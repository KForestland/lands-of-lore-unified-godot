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
 var puzzle=scene.get_node("L14Belial")
 paused=true;check(not puzzle.enter(),"paused elevator admission refuses");paused=false
 if not await walk(scene,[[25,5920]],"physical weighted-platform trigger approach"):quit(1);return
 if not check(puzzle.enter(),"source elevator transition from earned weighted floor"):quit(1);return
 check(not puzzle.enter(),"repeat admission refuses")
 for i in 30:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 check(scene.player.is_on_floor() and absf(scene.player.position.y-22)<2 and scene.player.position.distance_to(Vector3(42,22,11041))<4,"source lowered landing supports arrival")
 if not await walk(scene,[[42,11110],[42,11200]],"actual chamber approach after source transition"):quit(1);return
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_belial_entry_earned_save.json")
 if not check(error.is_empty(),"lower-hall approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_belial_entry_earned_save.json").is_empty(),"lower-hall approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("LOWER HALL APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned weighted descent -> source elevator transition -> actual chamber approach/save-reload")
 quit(0 if failures==0 else 1)
