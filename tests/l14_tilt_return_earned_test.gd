extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_tilt_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="ea21b6bea3e95eb2bfa6e1f5c380453e47ded4d581d3047a772aab9fafc09316","qualified two earned idols"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned middle idol input"):quit(1);return
 prepare(scene)
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_tilt_walk.json"));route.prize.reverse()
 if not await walk(scene,route.prize,"middle idol hall return"):quit(1);return
 if not await walk(scene,[[0,1250],[0,1100],[0,900],[0,612],[200,300],[200,-1000],[200,-1190],[140,-1320],[32,-1450],[32,-1600],[32,-2000],[32,-2170],[36,-2230]],"leveled source floors and original middle door return"):quit(1);return
 var tilt=scene.get_node("L14Tilt")
 for i in 60:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 check(tilt.state().settled==2 and tilt.left_offset()==0,"solved floor remains level after reload and return")
 check("act2:L14_HT:trial_idol371" in scene.carried_collected and "act2:L14_HT:trial_idol372" in scene.carried_collected,"both earned idols brought back")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_tilt_return_earned_save.json")
 if not check(error.is_empty(),"middle idol return save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_tilt_return_earned_save.json").is_empty(),"middle idol return reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("TWO IDOLS RETURN ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS two earned idols -> actual leveled floors/open original middle door return -> save/reload")
 quit(0 if failures==0 else 1)
