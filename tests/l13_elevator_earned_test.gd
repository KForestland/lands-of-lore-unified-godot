extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_basin_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="598af23bbeaddd78fd51bd2313ea4783d9a5a6e4c5ea9c543ad67e2375e04ca8","qualified basin input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned basin input"):quit(1);return
 prepare(scene)
 var lift=scene.get_node("L13Elevator")
 check(not lift.activate(2),"wrong Spark level refuses")
 var route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_elevator_walk.json"))
 if not await walk(scene,route.points,"elevator approach"):quit(1);return
 scene.camera.look_at(lift.aim(),Vector3.UP)
 paused=true;check(not lift.activate(),"paused elevator refuses");paused=false
 scene.starting_magic.select_spell("spark")
 if not check(scene.starting_magic.cast() and lift.state().started,"production Spark starts elevator"):quit(1);return
 check(not lift.activate(),"duplicate activation refuses")
 var height:float=lift.state().motion.height;paused=true
 for i in 12:await process_frame
 check(lift.state().motion.height==height,"paused elevator clock");paused=false
 for i in 120:
  scene.move_grounded(Vector3.ZERO,1.0/60.0);await physics_frame
 check(scene._quicksave_unrecorded("res://tmp/l13_elevator_moving_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_elevator_moving_earned_save.json").is_empty(),"moving elevator save/reload")
 for i in 900:
  scene.move_grounded(Vector3.ZERO,1.0/60.0);await physics_frame
  if lift.state().motion.remaining==0:break
 check(lift.state().motion.height==-1040,"source lower endpoint reached")
 check(absf(scene.player.position.y+1008)<8,"player physically rides descent")
 if not await walk(scene,[[-4860,3090],[-4860,2820],[-4839,2600],[-4839,2240]],"lower landing gate"):quit(1);return
 print("ELEVATOR_END ",scene.player.position," motion ",lift.state())
 check(scene._quicksave_unrecorded("res://tmp/l13_elevator_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_elevator_earned_save.json").is_empty(),"actual lower elevator save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds or recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned basin -> physical elevator approach -> actual Spark -> saved original floor descent -> lower landing/reload")
 quit(0 if failures==0 else 1)
