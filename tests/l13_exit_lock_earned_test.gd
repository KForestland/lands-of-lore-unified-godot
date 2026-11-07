extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_dawn_release_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="6ace2f6b19e8821944137b8225e154d6b5b1925e071f639330daa6f7209b1c4c","qualified Dawn-release input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Dawn-release input"):quit(1);return
 prepare(scene)
 var slot=scene.get_node("L13ExitLock")
 var stone:="act2:L13_RC:dreamstone"
 check(not slot.interact("insert",stone).ok,"remote slot refuses")
 var points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_exit_lift_return_walk.json"))
 if not await walk(scene,points,"Dawn to lower elevator"):quit(1);return
 var lift=scene.get_node("L13Elevator")
 scene.camera.look_at(lift.aim(),Vector3.UP)
 if not check(lift.reachable() and lift.activate(),"actual lower brain starts rise"):quit(1);return
 for i in 1200:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if lift.state().motion.remaining==0:break
 if not check(lift.state().motion.height==-40 and scene.player.position.y> -60,"actual platform carries player up"):quit(1);return
 if not await walk(scene,[[-4860,3200],[-4780,3300],[-4740,3500]],"upper landing"):quit(1);return
 points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_upper_ruloi_walk.json"))[0].points
 if not await walk(scene,points,"upper entrance route"):quit(1);return
 points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_exit_slot_walk.json"))
 if not await walk(scene,points,"original exit slot104"):quit(1);return
 scene.camera.look_at(slot.SLOT,Vector3.UP)
 check(not slot.interact("insert",scene.equipped_item).ok,"actual sword refused")
 paused=true;check(not slot.interact("insert",stone).ok,"paused slot refuses");paused=false
 if not check(slot.interact("insert",stone).ok,"earned stone commits exit slot"):quit(1);return
 check(stone not in scene.carried_collected and not slot.can_leave(),"stone occupies slot and departure waits for retrieval")
 var error:String=scene._quicksave_unrecorded("res://tmp/l13_exit_occupied_save.json")
 if not check(error.is_empty(),"occupied save: "+error):quit(1);return
 error=scene._quickload_unrecorded("res://tmp/l13_exit_occupied_save.json")
 if not check(error.is_empty(),"occupied reload: "+error):quit(1);return
 check(not slot.State.retrieve(slot.state(),scene.carried_collected,scene.carried_collected.size()).ok,"full inventory retrieval refuses without loss")
 scene.camera.look_at(slot.SLOT,Vector3.UP)
 if not check(slot.interact("retrieve").ok and slot.can_leave(),"same stone retrieved before departure"):quit(1);return
 check(not slot.interact("retrieve").ok and not slot.interact("insert",stone).ok,"duplicate slot actions refuse")
 check(scene._quicksave_unrecorded("res://tmp/l13_exit_retrieved_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_exit_retrieved_save.json").is_empty(),"retrieved slot save/reload")
 if not await walk(scene,[[-3260,6560],[-3260,6750]],"original exit region489"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"native exit request"):quit(1);return
 var change:Dictionary=scene.progression.level_changes.back()
 if not check(change.level==12 and change.selector==2,"native exit maps to Claw Mountains selector2"):quit(1);return
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change);await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene.carried_collected.count(stone)==1 and scene.equipped_item=="act2:L13_RC:dark_sword" and scene.carried_collected.count("act2:L13_RC:dawn_bestial_disk")==1,"stone/sword/gift survive actual exit")
 error=scene._quicksave_unrecorded("res://tmp/l13_exit_lock_earned_save.json")
 check(error.is_empty(),"Claw Mountains save: "+error)
 check(scene._quickload_unrecorded("res://tmp/l13_exit_lock_earned_save.json").is_empty(),"Claw Mountains reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Dawn stone ->physical elevator rise ->slot commit/retrieve ->native Claw Mountains exit/save-reload")
 quit(0 if failures==0 else 1)
