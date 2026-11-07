extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_exit_lock_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="b6cd377b098a4e96d1a099035336dcad82e4a08af41b4ec88359957e97033f58","qualified Citadel-exit input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Citadel-exit input"):quit(1);return
 prepare(scene)
 var points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_exit_cave_walk.json"))
 if not await walk(scene,points,"return ice cave"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l12_exit_cave_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l12_exit_cave_earned_save.json").is_empty(),"earned cave approach save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed/recovery")
 print("CAVE END ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Citadel exit ->physical return ice cave/save-reload")
 quit(0 if failures==0 else 1)
