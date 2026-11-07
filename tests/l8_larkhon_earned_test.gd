extends "res://tests/l9_chapel_earned_test.gd"
const Guardian=preload("res://scripts/lol2/l8_larkhon_state.gd")
func select_inventory(scene:Node,id:String)->bool:
 for i in scene.inventory.item_list.item_count:
  if scene.inventory.item_list.get_item_metadata(i)==id:scene.inventory.select_item(i);return true
 return false
func reached_waypoint(scene:Node,label:String,index:int)->void:
 super.reached_waypoint(scene,label,index)
 if label=="east river bank" and index==94:check(scene._quicksave_unrecorded("res://tmp/l8_larkhon_approach_earned_save.json").is_empty(),"earned river approach checkpoint")
 if label=="east river bank" and index==95:check(scene.request_jump(),"ordinary jump over low bank roots")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/act2_wild_village_qualified/l8_clubhouse_earned_save.json"
 if not check(FileAccess.get_sha256(path)=="02cfe975f0e0dcf98e60d23b4b9e403ef2ce701f200c01115be704568c0c58f6","qualified milestone2 anchor"):quit(1);return
 var input:=Save.read_save(path,"lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual clubhouse input"):quit(1);return
 prepare(scene)
 var guardian=scene.get_node("L8Larkhon");var before:Array=scene.carried_collected.duplicate()
 check(not guardian.offer("wrong").ok and scene.carried_collected==before,"remote offering refuses without loss")
 scene.progression._change_level({"level":12})
 check(scene.progression.native_log.back().get("owner")=="l8_larkhon","awake guardian refuses mountain exit")
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_larkhon_walk.json"))
 if not await walk(scene,route.leave,"leave clubhouse"):quit(1);return
 if not await walk(scene,route.bank,"east river bank"):quit(1);return
 for i in 120:
  await physics_frame
  var delta:Vector3=Vector3(5130,scene.player.position.y,1880)-scene.player.position
  if delta.length()<1:break
  scene.move_grounded(delta.normalized(),scene.player.get_physics_process_delta_time())
 for i in 180:
  await physics_frame;scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
  if scene.player.is_on_floor():break
 if not check(scene._quicksave_unrecorded("res://tmp/l8_larkhon_bank_earned_save.json").is_empty(),"earned river bank checkpoint"):quit(1);return
 if not check(scene.request_jump(),"ordinary Human river jump"):quit(1);return
 var airborne:=false;var landed:=false
 for i in 240:
  await physics_frame
  var delta:Vector3=Vector3(5400,scene.player.position.y,1850)-scene.player.position
  scene.move_grounded(delta.normalized() if delta.length()>3 else Vector3.ZERO,scene.player.get_physics_process_delta_time(),true)
  if not scene.player.is_on_floor():airborne=true
  if airborne and scene.player.is_on_floor():landed=true;break
 print("RIVER LAND ",scene.player.position)
 if not check(landed and scene.player.position.x>5370 and scene.player.position.y>-190 and scene.resets==0,"land on original lower east bank without recovery"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l8_larkhon_river_earned_save.json").is_empty(),"actual river landing saved")
 var serum:String=scene.carried_collected.filter(func(id):return Guardian.Items.definition(id)==119)[0]
 var leaf:String=scene.carried_collected.filter(func(id):return Guardian.Items.definition(id)==117)[0]
 check(not Guardian.mix(Guardian.initial(),[leaf,serum],serum,leaf).ok,"wrong ingredients refused")
 check(not Guardian.mix(Guardian.initial(),[leaf,serum],leaf,serum,0).ok,"no output capacity refuses atomically")
 check(Guardian.mix(Guardian.initial(),[leaf,serum],leaf,serum,2).ok,"full valid inventory trades two for one")
 if not check(scene.open_inventory(),"open actual mixing inventory"):quit(1);return
 if not check(select_inventory(scene,serum) and scene.inventory.mix_button.visible,"serum has recipe action"):quit(1);return
 scene.inventory.mix_button.pressed.emit();await process_frame
 if not check(Guardian.VAPORS in scene.carried_collected and leaf not in scene.carried_collected and serum not in scene.carried_collected,"Kit recipe produced original Vapors128"):quit(1);return
 if not check(scene.open_inventory(),"open activation inventory"):quit(1);return
 check(select_inventory(scene,Guardian.VAPORS) and scene.inventory.use_button.visible,"vapors have activation action")
 scene.inventory.use_selected_item();await process_frame
 check(guardian.state().active and Guardian.VAPORS in scene.carried_collected,"activation preserves carried dose")
 check(scene._quicksave_unrecorded("res://tmp/l8_larkhon_active_earned_save.json").is_empty(),"active dose save")
 check(scene._quickload_unrecorded("res://tmp/l8_larkhon_active_earned_save.json").is_empty(),"active dose reload")
 if not await walk(scene,route.rise,"Larkhon rise"):quit(1);return
 scene.camera.look_at(guardian.aim(),Vector3.UP)
 before=scene.carried_collected.duplicate()
 check(not guardian.offer("wrong").ok and scene.carried_collected==before,"wrong chest item refused without loss")
 paused=true;check(not guardian.offer(Guardian.VAPORS).ok,"paused offering refused");paused=false
 var gate_ray:=PhysicsRayQueryParameters3D.create(Vector3(7240,32,2160),Vector3(7340,32,2040),1<<9)
 check(not scene.get_world_3d().direct_space_state.intersect_ray(gate_ray).is_empty(),"awake original passage collision blocks entry")
 var result:Dictionary=guardian.offer(Guardian.VAPORS)
 if not check(result.ok,str(result)):quit(1);return
 await physics_frame
 check(scene.get_world_3d().direct_space_state.intersect_ray(gate_ray).is_empty(),"actual dose clears original passage collision")
 check(guardian.asleep() and Guardian.VAPORS not in scene.carried_collected,"original guardian sleeps after actual dose")
 check(scene.act2_creatures.state.actors["115"].health==5000,"guardian health unchanged")
 check(not guardian.offer(Guardian.VAPORS).ok,"dose cannot be applied twice")
 var sleep:float=guardian.state().sleep
 paused=true
 for i in 12:await process_frame
 check(is_equal_approx(guardian.state().sleep,sleep),"paused sleep clock");paused=false
 var asleep_path:="res://tmp/l8_larkhon_asleep_earned_save.json"
 check(scene._quicksave_unrecorded(asleep_path).is_empty(),"sleep save")
 check(scene._quickload_unrecorded(asleep_path).is_empty(),"sleep reload")
 if not await walk(scene,[[7195,2160],[7240,2160],[7290,2100],[7340,2040]],"sleeping guardian exit"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"native mountain exit fired"):quit(1);return
 var change:Dictionary=scene.progression.level_changes.back()
 check(change.level==12 and change.selector==1,"original L12 arrival1")
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change);await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene._quicksave_unrecorded("res://tmp/l12_larkhon_arrival_earned_save.json").is_empty(),"earned Claw Mountains arrival saved")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no resets or seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS qualified clubhouse -> physical east river Human jump -> inventory Kit recipe/activation -> original115 chest dose/sleep/reload -> native L12/1")
 quit(0 if failures==0 else 1)
