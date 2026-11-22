extends SceneTree
## Native-arrival input walks, not campaign completion: keep actors/hosts live; use W/mouse, M and the existing save API.
## After the earned walk/save receipt, a separately labelled full-area display probe exercises legacy Atlas migration.
const Places = preload("res://scripts/lol2/atlas_places.gd")
const Explored = preload("res://scripts/lol2/atlas_explored.gd")
const Visibility = preload("res://scripts/lol2/region_visibility.gd")
var scene
var area := ""
var failed := false
var receipt: Dictionary = {}
var destination := ""

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> bool:
 if not ok:
  failed = true
  push_error("Atlas %s: %s" % [area, label])
 return ok
func key(code: Key, pressed: bool) -> void:
 var e := InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.pressed=pressed
 Input.parse_input_event(e); Input.flush_buffered_events()
func tap(code: Key) -> void:
 key(code,true); await process_frame; key(code,false)
 for i in 3: await process_frame
func stand() -> Vector3:
 var p: Vector3 = scene.player.global_position
 if scene.get("native_translation") is Vector3: p -= scene.native_translation
 return p
func turn(to: Vector2) -> void:
 var p:=stand(); var off:=to-Vector2(p.x,p.z)
 var yaw:=atan2(-off.x,-off.y)
 var e:=InputEventMouseMotion.new()
 e.relative=Vector2(-angle_difference(scene.player.rotation.y,yaw)/0.003,scene.camera.rotation.x/0.003)
 Input.parse_input_event(e); Input.flush_buffered_events()
func walk_to(to: Vector2) -> bool:
 var best:=INF; var stalled:=0
 key(KEY_W,true)
 for frame in 450:
  if not is_instance_valid(scene) or current_scene!=scene:
   key(KEY_W,false); return check(false,"entry walk changed area")
  var p:=stand(); var distance:=Vector2(p.x,p.z).distance_to(to)
  if distance<8:
   key(KEY_W,false); return true
  if distance<best-0.3: best=distance; stalled=0
  else: stalled+=1
  if stalled>90: break
  turn(to)
  await physics_frame
 key(KEY_W,false)
 return false
func dismiss_museum_intro() -> void:
 # A live room contact may begin the clip during the walk; skip it before capturing the Atlas.
 for i in 600:
  if area!="L3_DH" or scene.introduction_state=="complete": break
  if i%30==0: await tap(KEY_ESCAPE)
  await process_frame
func open_atlas() -> Dictionary:
 for attempt in 3:
  await dismiss_museum_intro()
  if not (scene.interface_hud.sheet.visible and scene.interface_hud.atlas.visible): await tap(KEY_M)
  for i in 8: await process_frame
  if area!="L3_DH" or scene.introduction_state=="complete": break
 return scene.interface_hud.atlas.readable_report()
func close_atlas() -> void:
 await tap(KEY_M)
 for i in 3: await process_frame
func capture(tag: String) -> void:
 await RenderingServer.frame_post_draw
 var hud=scene.interface_hud
 check(hud.sheet.visible and hud.atlas.visible,"capture shows the open Atlas")
 check(area!="L3_DH" or scene.introduction_state=="complete","Museum clip is closed before Atlas capture")
 var viewport:=root.get_visible_rect().grow(1.0)
 check(viewport.encloses(hud.atlas_controls.get_global_rect()),"Atlas controls fit the viewport")
 check(hud.sheet.get_global_rect().grow(1.0).encloses(hud.atlas_controls.get_global_rect()),"Atlas controls stay inside the sheet below long titles")
 var image:=root.get_texture().get_image()
 var button_rect: Rect2=hud.atlas_controls.get_child(0).get_global_rect()
 var border_seen:=false
 # A scaled one-pixel border may rasterize on either side of its fractional layout edge.
 for offset in range(-2,3):
  var pixel:=Vector2i(roundi(button_rect.get_center().x),roundi(button_rect.position.y)+offset)
  var border:=image.get_pixelv(pixel)
  border_seen=border_seen or (border.r-border.b>0.04 and border.g-border.b>0.025)
 check(border_seen,"the Atlas button border is present in the rendered capture")
 image.save_png(destination+"/"+tag+".png")
func save_game(path: String) -> String:
 return scene._quicksave(path) if area=="L1_DC" else scene.quicksave(path)
func load_game(path: String) -> String:
 return scene._quickload(path) if area=="L1_DC" else scene.quickload(path)
func run() -> void:
 area=OS.get_environment("LOL2_ATLAS_AREA")
 var configs={"L1_DC":["cave_walkthrough",-1],"L3_DH":["museum_walkthrough",-1],"L5_HC":["hive_review",-1],"L9_DR":["dragon_level",1],"L10_DC":["maps/L10_DC",2],"L16_CA":["maps/L16_CA",1],"L17_HC":["maps/L17_HC",1],"L19_BC":["maps/L19_BC",1],"L20_BB":["maps/L20_BB",1]}
 if not check(configs.has(area),"area argument"): quit(1); return
 destination="user://tests/atlas_remaining/"+area
 DirAccess.make_dir_recursive_absolute(destination)
 var config: Array=configs[area]
 if int(config[1])>=0: set_meta("lol2_map_start_selector",int(config[1]))
 scene=load("res://scenes/lol2/%s.tscn"%config[0]).instantiate()
 if scene.get("adapter_exit_seeds")!=null: scene.adapter_exit_seeds=false
 if scene.get("development_mode")!=null: scene.development_mode=false
 root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if is_instance_valid(scene.get("interface_hud")) and is_instance_valid(scene.get("player")) and scene.get_node_or_null("AtlasExplored")!=null:break
 if not check(scene.get_node_or_null("AtlasExplored")!=null,"shared exploration tracker attached"):quit(1);return
 if scene.has_method("set_development_mode"): scene.set_development_mode(false)
 Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
 # Settle the original arrival under actual gravity before observing the Atlas.
 for i in 240:
  await physics_frame
  if i>30 and scene.player.is_on_floor():break
 if not check(Explored.area_of(scene)==area,"host area binding"):quit(1);return
 receipt={"area":area,"source_commit":OS.get_environment("LOL2_SOURCE_COMMIT"),"kind":"native-arrival input walk, not campaign chain","start":[stand().x,stand().y,stand().z],"walked":[]}
 var initial:=await open_atlas()
 check(not paused and bool(initial.get("filtering",false)),"Atlas filters a fresh arrival without pausing")
 # An interior arrival region may have only open neighbours. Walls appear when their boundary regions are explored.
 var wall_sides:=0
 for slice in scene.interface_hud.atlas.slices: wall_sides+=slice.walls.size()
 check(wall_sides>0,"native wall boundaries indexed")
 check(initial.get("places",[]).size()+initial.get("exits",[]).size()>0,"known arrival landmark/way visible")
 check(initial.get("places",[]).size()+initial.get("exits",[]).size()<Places.places(area).size(),"far landmarks stay hidden")
 if area in ["L1_DC","L9_DR","L17_HC"]:
  var atlas=scene.interface_hud.atlas
  var here:=int(initial.here)
  var projected:=Rect2();var first:=true
  for slice in atlas.slices:
   if int(slice.region)!=here:continue
   for point in slice.polygon:
    var pixel: Vector2=atlas.map_point(point)
    if first:projected=Rect2(pixel,Vector2.ZERO);first=false
    else:projected=projected.expand(pixel)
  check(not first and maxf(projected.size.x,projected.size.y)>=24,"the fresh arrival floor is readable, not an overview dot")
 receipt.initial=initial
 await capture("arrival")
 await close_atlas()
 # Select nearby source-neighbour centres from the live arrival. Blocked or steep links are refused; physics owns passage.
 var nav: Array=Visibility.load_regions(area)
 var blockers: Dictionary=scene.interface_hud.atlas.blocked
 var before: Dictionary=scene.atlas_explored.duplicate(true)
 var visited: Dictionary={}
 for leg in 6:
  var here:=Visibility.region_at_nav(nav,stand())
  if here<0:break
  visited[here]=true
  var candidates: Array=[]
  for edge in nav[here][3]:
   var next:=int(edge[0])
   if visited.has(next) or blockers.has(next) or absf(float(nav[next][1])-float(nav[here][1]))>32:continue
   var poly: Array=nav[next][0]
   if poly.is_empty():continue
   var to:=Vector2.ZERO
   for point in poly:to+=Vector2(point[0],point[1])
   to/=poly.size()
   if to.distance_to(Vector2(stand().x,stand().z))>180:continue
   candidates.append({"region":next,"to":to})
  var moved:=false
  for candidate in candidates:
   visited[candidate.region]=true
   if await walk_to(candidate.to):
    receipt.walked.append({"region":candidate.region,"point":[stand().x,stand().y,stand().z]});moved=true;break
  if not moved:break
 var after:=await open_atlas()
 check(receipt.walked.size()>0 and scene.atlas_explored!=before,"W/mouse walk explores additional source regions")
 check(not scene.flying,"walk stays grounded")
 receipt.after=after
 await capture("walked")
 await close_atlas()
 var path:=destination+"/walked_save.json"
 var save_error:=save_game(path)
 if not check(save_error.is_empty(),"walked save writes: "+save_error): quit(1); return
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 check(saved.has("atlas_explored") and not saved.get("quests",{}).has("atlas_explored"),"exploration is saved outside quest progress")
 check(load_game(path).is_empty(),"walked save reloads")
 var saved_explored: Dictionary=Explored.taken(saved,area)
 for id in saved_explored.areas.get(area,{}).get("regions",[]):
  check(id in scene.atlas_explored.areas.get(area,{}).get("regions",[]),"reload preserves explored region%d"%id)
 receipt.save_sha256=FileAccess.get_sha256(path)
 if scene.has_method("area_handoff"):
  # Exercise the actual earned exploration packet, not fabricated regions or a full-map fixture.
  var before_handoff:=Explored.stored(scene)
  var packet: Dictionary=scene.area_handoff()
  check(Explored.read_error(packet).is_empty() and Explored.taken(packet,area)==before_handoff,"area handoff retains exact earned exploration")
  var error: String=scene.apply_area_handoff(packet,false) if area=="L5_HC" else scene.apply_area_handoff(packet)
  check(error.is_empty() and Explored.stored(scene)==before_handoff,"area handoff reader restores that packet")
  var quests: Variant=scene.get("quest_state")
  if not quests is Dictionary: quests=scene.get("carried_quest_checkpoint")
  check(not quests.has("atlas_explored"),"handoff receiver removes transport-only exploration from runtime quests")
  receipt.handoff_preserved=true
 # Display-only fixture, after the earned save: old saves mark this area full; no quest/item/actor state is changed.
 var earned: Dictionary=scene.atlas_explored.duplicate(true)
 scene.atlas_explored=Explored.migrate({},area)
 var full:=await open_atlas()
 check(int(full.get("walls",0))>0,"full-area probe draws actual boundary walls")
 var places:=0;var exits:=0
 for row in Places.places(area):
  if row.kind=="exit":exits+=1
  else:places+=1
 check(full.get("places",[]).size()==places and full.get("exits",[]).size()==exits,"legacy full-area display shows every declared place/exit")
 receipt.full_display_probe=full
 await capture("full_display_probe")
 scene.atlas_explored=earned
 receipt.passed=not failed
 var f:=FileAccess.open(destination+"/receipt.json",FileAccess.WRITE);f.store_string(JSON.stringify(receipt,"  ")+"\n");f.close()
 if not failed:print("PASS Atlas ",area,": native arrival -> W/mouse exploration -> M, walls/hidden places, save/reload; separate full-area display probe")
 scene.queue_free();await process_frame
 quit(1 if failed else 0)
