extends "res://tests/l12_citadel_earned_test.gd"
## BJ05 (lead 2026-11-08): the Claw Mountains main chain walked in ONE sitting like a player, from the native L12 arrival
## (the Larkhon pass, selector 1, the bottom of the icy gulch; longplay g_00169) to the native L13 Citadel arrival.
## The per-step earned tests remain the qualification of each mechanism (they relay from qualified saves); this walk
## proves the chain holds for a player who never leaves the level: the hint the player sees at each stop, the same
## E key / inventory / right-click the player uses, a quicksave + reload at every stop (save -> load -> save is
## stable up to float print noise, position and inventory persist), no fall recovery, no seeds. Stops (hint book ch. 11 order):
## arrival -> gulch ramp + raised crossing -> lower valley -> glacier entry (the floor drops) -> right wall + ice caves ->
## Kenneth (search, throw the picture) -> ice-platform hops -> far cave -> Baccata -> citadel entrance (movie 13) -> L13.
const OUT:="res://tmp/l12_chain_"
const E_KEY:=KEY_E
var stops:Array[String]=[]
var glacier_message:=""
## The 3-second HUD notice the glacier trigger shows is read at the first waypoint after it fires, as the player reads it.
func reached_waypoint(scene:Node,label:String,index:int)->void:
 super.reached_waypoint(scene,label,index)
 if label=="glacier entry" and glacier_message.is_empty() and scene.get_node("L12Glacier").state().started:glacier_message=feedback(scene)
func press_key(keycode:int)->void:
 var e:=InputEventKey.new();e.keycode=keycode;e.physical_keycode=keycode;e.pressed=true
 Input.parse_input_event(e);Input.flush_buffered_events()
 await process_frame
 var up:=InputEventKey.new();up.keycode=keycode;up.physical_keycode=keycode;up.pressed=false
 Input.parse_input_event(up);Input.flush_buffered_events()
 await process_frame
func right_click()->void:
 var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_RIGHT;e.pressed=true
 Input.parse_input_event(e);Input.flush_buffered_events()
 await process_frame
 var up:=InputEventMouseButton.new();up.button_index=MOUSE_BUTTON_RIGHT;up.pressed=false
 Input.parse_input_event(up);Input.flush_buffered_events()
 await process_frame
## Reloaded state equal to the saved one: numbers within float print noise (a legacy Hive fraction prints 2.7755575615628914e-14
## on one write and 2.775557561562891e-14 after a parse), everything else exact.
## 5bcd609 (2026-11-14): a successful load releases the half-second cast lock by design (game_session finish_load), so
## the re-save holds cooldown 0. Compare with that one documented release applied; every other value must match.
func released(save:Variant)->Variant:
 if save is Dictionary and save.get("quests") is Dictionary and save.quests.get("player_magic_reward_state") is Dictionary:
  save.quests.player_magic_reward_state.cooldown=0.0
 return save
func same(a:Variant,b:Variant)->bool:
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for k in a:
   if not b.has(k) or not same(a[k],b[k]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not same(a[i],b[i]):return false
  return true
 if (a is float or a is int) and (b is float or b is int):return is_equal_approx(float(a),float(b))
 return a==b
## The level change after the movie: the skip closes the overlay, the deferred native change happens within a frame or two
## and frees the old scene, so the new scene is polled by area (scene_changed may already have fired).
func await_level(area:String)->Node:
 for i in 3000:
  await process_frame
  var next:Variant=current_scene
  if next!=null and is_instance_valid(next) and str(next.get("area_id"))==area:
   for j in 1500:
    await process_frame
    if not is_instance_valid(next) or next.ready_for_review:break
   return next
 return null
func feedback(scene:Node)->String:return scene.interface_hud.hint.text if is_instance_valid(scene.interface_hud) else ""
## A player's F5 then F9 at this stop: the save reloads to the same world (a second save holds the same state), the
## position and the inventory persist, and nothing recovered or seeded the walk so far.
func checkpoint(scene:Node,name:String)->bool:
 var path:=OUT+name+"_save.json"
 var pos:Vector3=scene.player.position
 var carried:Array=scene.carried_collected.duplicate()
 if not check(scene._quicksave_unrecorded(path).is_empty(),"quicksave at "+name):return false
 var first:=FileAccess.get_file_as_string(path)
 if not check(scene._quickload_unrecorded(path).is_empty(),"reload at "+name):return false
 var again:=OUT+name+"_again_save.json"
 if not check(scene._quicksave_unrecorded(again).is_empty(),"second quicksave at "+name):return false
 check(same(released(JSON.parse_string(first)),JSON.parse_string(FileAccess.get_file_as_string(again))),"save -> load -> save stable at "+name)
 var persisted:bool=check(scene.player.position.distance_to(pos)<0.1 and scene.carried_collected==carried,"position and inventory persist at "+name)
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no fall recovery or seeds up to "+name)
 stops.append(name)
 print("STOP ",name," at ",scene.player.position," region ",scene.progression.region_at(scene.player.position)," events ",scene.progression.route_log.size())
 return persisted
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var start:="res://tmp/l12_larkhon_arrival_earned_save.json"
 var input=Save.read_save(start,"lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 if not check(int(input.state.quests.get("l8_baccata",{}).get("phase",0))==3,"the L8 trap rescue was earned before the pass (Baccata appears only then)"):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Larkhon-pass arrival"):quit(1);return
 prepare(scene)
 var citadel=scene.get_node("L12Citadel");var glacier=scene.get_node("L12Glacier")
 var gulch=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_gulch_walk.json"))
 var ice=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_ice_route.json"))
 var approach=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_citadel_walk.json"))
 # 1. Arrival: the bottom of the icy gulch (native selector 1, region 735).
 check(scene.progression.region_at(scene.player.position)==735,"arrival stands in the native arrival region 735")
 check(not citadel.state().searched and not citadel.state().talked,"fresh citadel approach")
 if not checkpoint(scene,"arrival"):quit(1);return
 # 2. Climb a ravine, the north-east path, the raised crossing (the non-gorilla branch; book 3924-3926).
 if not await walk(scene,gulch.points,"gulch climb"):quit(1);return
 if not await walk(scene,gulch.bridge,"original raised crossing"):quit(1);return
 if not checkpoint(scene,"gulch"):quit(1);return
 # 3. The lower valley to the glacier entry: the floor gives way on entry; keep to the right-hand wall (book 3972-3974).
 if not await walk(scene,ice.valley,"lower valley path"):quit(1);return
 if not checkpoint(scene,"valley"):quit(1);return
 if not await walk(scene,ice.entry,"glacier entry"):quit(1);return
 if not check(glacier.state().started,"entering the valley starts the glacier floor drop"):quit(1);return
 check(glacier_message.begins_with("The glacier gives way"),"the player is told to keep to the right-hand wall: '"+glacier_message+"'")
 if not checkpoint(scene,"glacier_entry"):quit(1);return
 if not await walk(scene,ice.right_wall,"glacier right wall and caves"):quit(1);return
 check(glacier.state().motion.height==-1090 and glacier.state().motion.remaining==0,"glacier floor reached its source target")
 if not checkpoint(scene,"ice_caves"):quit(1);return
 # 4. Kenneth's body where the ice caves end: the E prompt, the search, the picture readied from the inventory, thrown with a right-click.
 scene.camera.look_at(citadel.BODY+Vector3.UP*12,Vector3.UP)
 for i in 3:await process_frame
 if not check(citadel.hint.text=="E — Search Kenneth","Kenneth prompt shown at the body: '"+citadel.hint.text+"'"):quit(1);return
 await press_key(E_KEY)
 if not check(citadel.state().searched and citadel.State.PICTURE in scene.carried_collected,"E searches Kenneth and yields the picture"):quit(1);return
 check(feedback(scene).begins_with("You find a picture"),"search feedback: '"+feedback(scene)+"'")
 if not checkpoint(scene,"kenneth_searched"):quit(1);return
 if not check(scene.open_inventory(),"open the inventory"):quit(1);return
 var selected:=false
 for i in scene.inventory.item_list.item_count:
  if scene.inventory.item_list.get_item_metadata(i)==citadel.State.PICTURE:scene.inventory.select_item(i);selected=true;break
 if not check(selected and scene.inventory.use_button.visible,"the picture offers a use action"):quit(1);return
 scene.inventory.use_selected_item();await process_frame
 if not check(citadel.state().armed and not is_instance_valid(scene.inventory),"using the picture arms the throw and closes the inventory"):quit(1);return
 for i in 3:await process_frame
 check(citadel.hint.text=="Right click — Throw picture at the ground","throw prompt shown: '"+citadel.hint.text+"'")
 scene.camera.look_at(scene.player.position+Vector3(25,-30,25),Vector3.UP)
 await right_click()
 if not check(citadel.State.CHARM in scene.carried_collected and citadel.State.PICTURE not in scene.carried_collected,"right-click breaks the picture into Kenneth's charm"):quit(1);return
 check(feedback(scene).begins_with("The picture breaks"),"charm feedback: '"+feedback(scene)+"'")
 if not checkpoint(scene,"kenneth_charm"):quit(1);return
 # 5. The ice ledge: platform hops and the running leap into the far cave as the Human (book 3989).
 if not await walk(scene,[[4535,-14170]],"cave lip"):quit(1);return
 for p in ice.ice:
  if not await hop(scene,Vector2(p[0],p[1]),p[2]):quit(1);return
  if not await walk(scene,[[p[0],p[1]]],"ice platform center"):quit(1);return
 if not checkpoint(scene,"ice_platforms"):quit(1);return
 if not await walk(scene,[[3615,-15030]],"last ice ledge"):quit(1);return
 if not await hop(scene,Vector2(3490,-14955),-930):quit(1);return
 if not checkpoint(scene,"far_cave"):quit(1);return
 # 6. The twisting ice tunnel to Baccata (book 3993): he stands there because the L8 rescue was earned; E hears him out.
 if not await walk(scene,approach.baccata,"Baccata ice tunnel"):quit(1);return
 if not check(citadel.state().baccata_seen and scene.act2_creatures.state.actors["30"].present,"rescued Baccata stands in the ice tunnel"):quit(1);return
 scene.camera.look_at(citadel.BACCATA+Vector3.UP*50,Vector3.UP)
 for i in 3:await process_frame
 if not check(citadel.hint.text=="E — Speak with Baccata","Baccata prompt shown: '"+citadel.hint.text+"'"):quit(1);return
 await press_key(E_KEY)
 if not check(citadel.state().talked,"E hears Baccata's account"):quit(1);return
 check(feedback(scene).begins_with("You listen to Baccata"),"Baccata feedback: '"+feedback(scene)+"'")
 if not checkpoint(scene,"baccata"):quit(1);return
 # 7. The citadel entrance: original control 74 -> movie 13 CITADEL (paused world, saves refused) -> native L13 arrival 1.
 if not await walk(scene,approach.entrance,"citadel entrance"):quit(1);return
 scene.camera.look_at(citadel.entrance_aim(),Vector3.UP)
 if not check(scene.progression.aimed_exit()=="control:74","the citadel entrance is the aimed E target"):quit(1);return
 if not checkpoint(scene,"citadel_entrance"):quit(1);return
 var before_change:int=scene.progression.level_changes.size()
 scene.progression.change_scene_enabled=true
 scene.progression.use_exit("control:74") # E on the aimed exit (the binder's own E needs a captured mouse, which headless cannot give).
 for i in 90:
  await process_frame
  if is_instance_valid(scene.video_overlay):break
 if not check(is_instance_valid(scene.video_overlay) and paused,"the CITADEL movie starts and freezes the world"):quit(1);return
 check(scene.progression.level_changes.size()==before_change+1 and scene.progression.level_changes.back().level==13 and scene.progression.level_changes.back().selector==1,"the native command names L13 arrival 1")
 check(scene._quicksave_unrecorded(OUT+"during_movie_save.json")=="Close the current overlay before saving.","F5 during the movie is refused with the overlay message")
 for i in 15:await process_frame
 check(scene.video_overlay.video.is_playing(),"the original movie is playing")
 await press_key(KEY_SPACE) # The player may skip; the full 591 frames are l12_citadel_earned_test's proof.
 scene=await await_level("L13_RC")
 if not check(scene!=null,"the L13 scene arrives after the movie"):quit(1);return
 prepare(scene)
 if not check(scene.area_id=="L13_RC","native L13 arrival after the movie"):quit(1);return
 check(scene.quest_state.l12_citadel.movie_seen and scene.quest_state.l12_citadel.talked,"citadel receipts travel to L13")
 check(preload("res://scripts/lol2/l12_citadel_state.gd").CHARM in scene.carried_collected,"Kenneth's charm reaches the citadel")
 check(int(scene.quest_state.get("l8_baccata",{}).get("phase",0))==3,"the L8 rescue receipt travels to L13")
 if not checkpoint(scene,"l13_arrival"):quit(1);return
 var statuses:Dictionary={}
 for row in scene.progression.route_log:
  for r in row.results:statuses[r.status]=int(statuses.get(r.status,0))+1
 print("L13 route_log statuses ",statuses)
 scene.queue_free();await process_frame
 if failures==0:print("PASS L12 main chain in one sitting: native arrival -> gulch -> valley -> glacier drop -> ice caves -> Kenneth (E, inventory, right-click) -> ice hops -> far cave -> Baccata (E) -> citadel movie -> native L13 arrival; %d stops saved and reloaded to the same state"%stops.size())
 quit(0 if failures==0 else 1)
