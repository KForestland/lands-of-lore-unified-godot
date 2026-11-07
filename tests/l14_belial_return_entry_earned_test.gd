extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_hopper_platform_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="f594ccfa6a5c7526b4be0d2a74ab6d1e125f8ea0288dcb2494d23e3f91e670d6","qualified weighted platform descent"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned weighted platform input"):quit(1);return
 prepare(scene)
 var puzzle=scene.get_node("L14HopperPlatform")
 scene.camera.look_at(puzzle.return_point(),Vector3.UP)
 paused=true;check(not puzzle.return_to_gallery().ok,"paused return refuses");paused=false
 if not check(puzzle.return_to_gallery().ok,"local original reset-height return adapter"):quit(1);return
 check(not puzzle.return_to_gallery().ok,"repeat return refuses")
 for i in 60:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 var before:float=puzzle.return_state().raised
 paused=true
 for i in 8:await process_frame
 check(puzzle.return_state().raised==before,"return motion pauses");paused=false
 var err:String=scene._quicksave_unrecorded("res://tmp/l14_pressure_return_moving_save.json")
 if not check(err.is_empty(),"moving return save: "+err):quit(1);return
 if not check(scene._quickload_unrecorded("res://tmp/l14_pressure_return_moving_save.json").is_empty(),"moving return reload"):quit(1);return
 for i in 300:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 check(puzzle.return_state().raised==4 and scene.player.is_on_floor() and absf(scene.player.position.y-332)<2,"actual return ride to floor300")
 var encounter=scene.get_node("L14Belial")
 if not check(encounter.enter(),"completed physical return still admits source chamber transition"):quit(1);return
 for i in 30:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 check(scene.player.position.distance_to(Vector3(42,22,11041))<4 and scene.player.is_on_floor(),"settled source chamber arrival after optional return")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_belial_return_entry_earned_save.json")
 if not check(error.is_empty(),"lower-hall approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_belial_return_entry_earned_save.json").is_empty(),"lower-hall approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("LOWER HALL APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned weighted descent -> actual physical return -> source chamber admission remains available/save-reload")
 quit(0 if failures==0 else 1)
