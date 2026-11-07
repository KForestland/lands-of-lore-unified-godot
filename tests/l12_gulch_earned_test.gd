extends "res://tests/l9_chapel_earned_test.gd"
func reached_waypoint(scene:Node,label:String,index:int)->void:
 super.reached_waypoint(scene,label,index)
 if label=="original raised crossing":check(scene.player.position.y>105,"original raised deck supports crossing")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 if not check(FileAccess.get_sha256("res://tmp/l12_larkhon_arrival_regression_anchor.json")=="de88903cf254873c19988dbeb90aa86c5322cf9ed1ceb819aa4bf6d0e0ab2db6","qualified STORY035 anchor"):quit(1);return
 var input=Save.read_save("res://tmp/l12_larkhon_arrival_regression_anchor.json","lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned arrival"):quit(1);return
 prepare(scene)
 var route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_gulch_walk.json"))
 var carried:Array=scene.carried_collected.duplicate()
 if not await walk(scene,route.points,"gulch climb"):quit(1);return
 if not await walk(scene,route.bridge,"original raised crossing"):quit(1);return
 var pos:Vector3=scene.player.position
 var path:="res://tmp/l12_gulch_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"earned non-gorilla fork save/reload")
 check(scene.player.position.distance_to(pos)<0.1 and scene.carried_collected==carried,"actual position and carried inventory persist")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no recovery or seeds")
 if failures==0:print("PASS earned L12 arrival -> original gulch ramp -> east branch across original controls113/112/110/107/109/111/106/108 -> saved non-gorilla path")
 scene.queue_free();await process_frame;quit(0 if failures==0 else 1)
