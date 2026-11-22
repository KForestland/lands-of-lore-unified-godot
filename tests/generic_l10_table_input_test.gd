extends "res://tests/generic_prop_input_test.gd"
## Table-driven rendered components. Supplied grounded vantages, held NPC/root
## clocks during setup, live support/jump/melee windows, game-written inventory.
## These are not earned-route evidence.
const Catalog=preload("res://scripts/lol2/generic_object_catalog.gd")
var table_receipts:Array=[]
func free_at(at:Vector3)->bool:
 var collider:CollisionShape3D=scene.player.get_child(0)
 var query:=PhysicsShapeQueryParameters3D.new()
 query.shape=collider.shape.duplicate();query.shape.height-=0.1
 query.transform=Transform3D(scene.player.global_basis,at)*Transform3D(Basis.IDENTITY,collider.position+Vector3.UP*0.05)
 query.collision_mask=scene.player.collision_mask;query.exclude=[scene.player.get_rid()]
 return scene.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
func candidate_drawn(_kind:String,_id:int)->bool:return true # Derived room gate additionally requires actual artwork.
func stand_for(point:Vector3,kind:String,id:int)->bool:
 var world:Node=scene.get_node("GenericObjects")
 var radii:Array=[120.0,96.0,80.0,64.0,48.0,32.0,24.0] if kind=="movable" else [24.0,32.0,48.0,64.0,80.0,96.0,120.0]
 for radius in radii:
  for direction in 16:
   var side:Vector3=point+Vector3(sin(direction*TAU/16),0,cos(direction*TAU/16))*radius
   var ray:=PhysicsRayQueryParameters3D.create(side+Vector3.UP*10,side-Vector3.UP*240,1|256,[scene.player.get_rid()])
   var floor_hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
   if floor_hit.is_empty() or floor_hit.normal.y<0.7:continue
   var at:Vector3=floor_hit.position+Vector3.UP*32.05
   if not free_at(at):continue
   if not await pose(at,point):return false
   if not player_clear():continue
   # Physics settling can reconcile the eye height. Re-aim from that final
   # eye before admitting the vantage later used for the actual click.
   await aim(point)
   var matches:=false
   if kind in ["movable","cover"]:
    var target:Dictionary=world.aimed()
    matches=target.get("kind")==kind and int(target.get("id",-1))==id
    if kind=="cover":matches=matches and float(target.get("distance",INF))<=preload("res://scripts/lol2/player_combat.gd").REACH_PROP
   elif kind=="item":matches=scene.act2_items.target()=="act2:L10_DC:item%d"%id
   elif kind=="emperor":matches=scene.get_node("L10Emperor").target()==str(id)
   if matches and candidate_drawn(kind,id):
    print("TABLE VANTAGE ",kind,id," at=",scene.player.position," aim=",point)
    return true
 return check(false,"No physically exposed grounded component vantage for %s%d; no row skipped"%[kind,id])
func player_clear()->bool:
 var collider:CollisionShape3D=scene.player.get_child(0)
 var shape:Shape3D=collider.shape.duplicate();shape.height-=0.1
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape
 query.transform=collider.global_transform;query.transform.origin.y+=0.05
 query.collision_mask=scene.player.collision_mask;query.exclude=[scene.player.get_rid()]
 var hits:Array=scene.get_world_3d().direct_space_state.intersect_shape(query)
 if not hits.is_empty():print("CONTACT overlaps=",hits," player=",scene.player.position)
 return hits.is_empty()
func contact_case(id:int)->bool:
 # RealE closes the previously opened lid before the supplied on-lid contact
 # vantage. Root physics then stays live through the moving support case.
 var center:Vector3=scene.progression.hinges[id].transform*scene.progression.mover_bounds[id].get_center()
 await aim(center);await key(KEY_E)
 for tick in 60:await physics_frame
 if not check(int(state(id)[Rules.PHASE])==5,"Contact fixture closes the lid by realE"):return false
 center=scene.progression.hinges[id].transform*scene.progression.mover_bounds[id].get_center()
 if not await pose(center+Vector3.UP*36.05,center):return false
 scene.set_physics_process(true)
 for tick in 6:await physics_frame
 if not check(scene.player.is_on_floor() and player_clear(),"Contact case starts grounded and not embedded"):return false
 var start:Vector3=scene.player.position
 var mover_start:Vector3=scene.progression.hinges[id].global_position
 await aim(center);await key(KEY_E)
 for tick in 90:
  await physics_frame
  if not check(scene.resets==0 and scene.starting_magic.health()>0 and player_clear(),"Moving lid never embeds Luther or causes a floor reset"):return false
 var end:Vector3=scene.player.position
 var platform_delta:Vector3=scene.progression.hinges[id].global_position-mover_start
 print("CONTACT CARRY player=",end-start," platform=",platform_delta," phase=",state(id)[Rules.PHASE])
 if not check((end-start-platform_delta).length()<1.0,"The live rider is carried once, matching the platform displacement"):return false
 if not check(int(state(id)[Rules.PHASE])==1 and absf(end.z-start.z)>20 and absf(end.y-start.y)<1.0,"Lid actually moves while supporting the player's live body"):return false
 scene.set_physics_process(false)
 table_receipts.append({"kind":"contact","id":id,"start":str(start),"end":str(end),"resets":scene.resets,"clear":true})
 return true
func jump_content(identity:String,at:Array)->bool:
 var stand:=Vector3(at[0],at[1],at[2])
 if not check(free_at(stand),"The disclosed component jump begins in clear real ground space"):return false
 if not await pose(stand,scene.act2_items.aim_point(identity)):return false
 scene.set_physics_process(true)
 await key(KEY_SPACE)
 var taken:=false
 for tick in 160:
  await aim(scene.act2_items.aim_point(identity))
  if scene.act2_items.available(identity):
   await key(KEY_E)
   if identity in scene.carried_collected:taken=true;break
  if tick>8 and scene.player.is_on_floor():break
 for tick in 180:
  await physics_frame
  if scene.player.is_on_floor():break
 scene.set_physics_process(false)
 return check(taken and scene.player.is_on_floor() and player_clear() and scene.resets==0,"Actual Space/E takes high contents and lands without embedding/recovery")
func run():
 if not check(DisplayServer.get_name()!="headless","Rendered table driver"):return
 folder="user://tests/generic_l10_table";DirAccess.make_dir_recursive_absolute(folder)
 if not await boot("res://scenes/lol2/maps/L10_DC.tscn","res://assets/lol2/generated/playtest_starts/c15_l10_dc.json","6f9d174047977927af32457ccbb2e9df1ef332974e02b7adcf915854d25ea49f","lol2-restoration-map-L10_DC"):return
 var world:Node=scene.get_node("GenericObjects")
 var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/generic_l10_acceptance_rows.json"))
 for row in source.movables:
  var id:int=int(row.id)
  if not check(Catalog.movables("L10_DC").has(id),"Requested row belongs to approved movable census"):return
  var point:Vector3=scene.progression.hinges[id].transform*scene.progression.mover_bounds[id].get_center()
  if not await stand_for(point,"movable",id):return
  if not check(int(state(id)[Rules.PHASE])==0,"Closed precondition "+str(id)):return
  if id==85:
   # Admission fixture only; no body/curse claim. Both nonhuman forms must
   # refuse the same actual E before the Human positive control.
   for form in [1,2]:
    scene.player_form=form
    await key(KEY_E)
    if not check(int(state(id)[Rules.PHASE])==0,"Nonhuman form refuses generic use"):return
   scene.player_form=0
  await key(KEY_E)
  for tick in 60:await physics_frame
  if not check(int(state(id)[Rules.PHASE])==1,"ActualE opens table movable%d"%id):return
  table_receipts.append({"kind":"movable","id":id,"real_input":"E","phase":1})
  await shot("open%d"%id)
  if id==52 and not await contact_case(id):return
 # Declared component aid: validated Champion effect fixture supplies the
 # review's actual 28-damage weapon case. No earned-walk claim.
 var bonus_fixture:Dictionary=AreaSave.snapshot_host(scene)
 bonus_fixture.inventory.item_effects.champion={"version":1,"active":true,"timer":3600*65536}
 if not check(scene.apply_save(bonus_fixture).is_empty(),"Declared Champion-state fixture validates"):return
 for row in source.covers:
  var id:int=int(row.id)
  if not check(preload("res://scripts/lol2/player_combat.gd").damage(scene,true)==28,"Champion fixture really supplies the review 28-damage case"):return
  if not check(Catalog.breakables("L10_DC").has(id),"Requested row belongs to approved cover census"):return
  var point:Vector3=world.cover_bodies[id].global_position
  if not await stand_for(point,"cover",id):return
  scene.act2_creatures.set_physics_process(true)
  var losses:Array=[]
  for strike_index in 40:
   var before:int=scene.progression.native.field("control:%d"%id,scene.progression.NativeHost.FIELD_BYTE26,0)
   if before==0:break
   await aim(point)
   var admitted:Dictionary=world.aimed()
   if admitted.get("kind")!="cover" or int(admitted.get("id",-1))!=id or float(admitted.get("distance",INF))>preload("res://scripts/lol2/player_combat.gd").REACH_PROP:
    # Cover5's native threshold lowers a floor. The component pose is an aid,
    # not a promise that the original stand stays usable after native effects.
    print("TABLE REACQUIRE after native effect id=",id," life=",before," player=",scene.player.position," aimed=",admitted)
    scene.act2_creatures.set_physics_process(false)
    if not await stand_for(point,"cover",id):return
    scene.act2_creatures.set_physics_process(true)
   for tick in 90:
    await physics_frame
    if scene.act2_creatures.strike_remaining<=0:break
   await aim(point);await click()
   var after:int=scene.progression.native.field("control:%d"%id,scene.progression.NativeHost.FIELD_BYTE26,0)
   if after!=maxi(0,before-28):print("TABLE STRIKE REFUSED id=",id," life=",before,"->",after," hp=",scene.starting_magic.health()," active=",world.active()," aimed=",world.aimed()," cooldown=",scene.act2_creatures.strike_remaining," pos=",scene.player.position," camera=",scene.camera.rotation)
   if not check(after==maxi(0,before-28),"Actual 28-damage click crosses bands on cover%d"%id):return
   losses.append([before,after])
  scene.act2_creatures.set_physics_process(false)
  var final_art:bool=world.cover_modes[id]==3
  if int(Catalog.breakables("L10_DC")[id].template)==66:
   final_art=not world.renderer.presence[id]
   for mesh in world.renderer.stateful_meshes.get(id,[]):final_art=final_art and not mesh.visible
  if not check(scene.progression.native.field("control:%d"%id,scene.progression.NativeHost.FIELD_BYTE26,1)==0 and world.cover_bodies[id].collision_layer==0 and final_art,"Broken table front has matching final artwork and admits pickups"+str(id)):return
  table_receipts.append({"kind":"cover","id":id,"real_input":"left","life":0,"solid":false,"losses":losses})
  await shot("broken%d"%id)
  if row.get("contents")!=null:
   var contents:String="act2:L10_DC:item%d"%int(row.contents)
   if row.has("content_jump_stand"):
    if not await jump_content(contents,row.content_jump_stand):return
   else:
    if not await stand_for(scene.act2_items.aim_point(contents),"item",int(row.contents)):return
    await aim(scene.act2_items.aim_point(contents))
    if not check(scene.act2_items.available(contents),"Broken front%d admits its original item from an exposed grounded component vantage"%id):return
    await key(KEY_E)
   if not check(contents in scene.carried_collected,"RealE takes original contents behind broken front%d"%id):return
   table_receipts.append({"kind":"cover_contents","cover":id,"item":contents,"real_input":"Space/E" if row.has("content_jump_stand") else "E"})
 for row in source.items:
  var id:int=int(row.id);var identity:String="act2:L10_DC:item%d"%id
  if not await stand_for(scene.act2_items.aim_point(identity),"item",id):return
  await key(KEY_E)
  if not check(identity in scene.carried_collected,"Actual E takes table globe%d"%id):return
  table_receipts.append({"kind":"item","id":id,"real_input":"E","taken":true})
  await shot("taken%d"%id)
 # A separate genuine late checkpoint supplies the real three charged globes
 # and retained ankh. The driver still uses only E/left for each transaction.
 if not await boot("res://scenes/lol2/maps/L10_DC.tscn","res://tmp/generic_l10_inputs/l10_emperor_boxes_earned_save.json","9157547c336ccce9674ac86b27ea66f66f674e813b036fdb429ac81fa5207b14","lol2-restoration-map-L10_DC"):return
 var emperor:Node=scene.get_node("L10Emperor")
 if not check(emperor.State.count(emperor.state())==0,"Genuine three-globe packet starts with unfilled boxes"):return
 for row in source.emperor:
  var id:int=int(row.id)
  if not await stand_for(emperor.AIMS[str(id)],"emperor",id):return
  await key(KEY_E)
  if id!=143:
   if not check(not emperor.State.Kit.slot(emperor.state(),str(id)).occupied.is_empty() and int(emperor.renderer.modes[id])==3,"ActualE fills colour box%d and shows source art"%id):return
  elif not check(emperor.State.opened(emperor.state()) and int(emperor.renderer.modes[143])==1,"ActualE uses retained ankh on door143 after all colours"):return
  table_receipts.append({"kind":"emperor","id":id,"real_input":"E"})
  await shot("emperor%d"%id)
 if not check(scene.resets==0 and scene.starting_magic.health()>0,"No fall resets or deaths in table components"):return
 var f:=FileAccess.open(folder+"/receipt.json",FileAccess.WRITE);f.store_string(JSON.stringify({"component_only":true,"rows":table_receipts,"resets":scene.resets},"  "));f.close()
 print("PASS B table-driven actual E/left covers every requested crypt/lid/front/globe row, final art/collision; supplied clear grounded vantages with disclosed live support/jump/melee windows, not earned walking")
 quit()
