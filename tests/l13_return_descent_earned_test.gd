extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_return_pad_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="192f8d98753668a6af178b29a6c7cb934085137ee9b46ae277275c324cb37fed","qualified return-pad input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned return-pad input"):quit(1);return
 prepare(scene)
 var lift=scene.get_node("L13Elevator")
 check(not lift.call_upper(),"remote upper call refused")
 var points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_return_lift_walk.json"))
 if not await walk(scene,points,"upper call landing"):quit(1);return
 scene.camera.look_at(lift.BRAIN,Vector3.UP)
 print("CALL debug pos",scene.player.position," floor",scene.player.is_on_floor()," state",lift.state()," active",scene.starting_magic.world_active()," reach",lift.upper_call_reachable())
 if not check(lift.call_upper() and lift.state().motion.remaining>0,"physical upper landing calls real platform"):quit(1);return
 for i in 1200:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if lift.state().motion.remaining==0:break
 if not check(lift.state().motion.height==-40 and scene.player.position.y> -60,"platform rises while player waits on upper landing"):quit(1);return
 if not await walk(scene,[[-4860,3090]],"board risen platform"):quit(1);return
 scene.camera.look_at(lift.aim(),Vector3.UP)
 if not check(lift.reachable() and lift.activate(),"actual brain starts descent"):quit(1);return
 for i in 1200:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if lift.state().motion.remaining==0:break
 if not check(lift.state().motion.height==-1040 and scene.player.position.y< -995,"player rides actual descending platform"):quit(1);return
 if not await walk(scene,[[-4860,2820],[-4839,2600],[-4839,2240]],"lower return exit"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l13_return_descent_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_return_descent_earned_save.json").is_empty(),"earned descent save-reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned altar return ->physical upper call ->real elevator rise/descent ->lower exit/save-reload")
 quit(0 if failures==0 else 1)
