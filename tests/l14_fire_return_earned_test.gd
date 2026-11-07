extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_fire_paths_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="6b62b20e3cafc9db73015b286d2c36df115bb32384765e289d87c1a32b519765","qualified three earned idols"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned third idol input"):quit(1);return
 prepare(scene)
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_fire_paths_walk.json"))
 route["4103"].reverse()
 if not await walk(scene,route["4103"],"third idol hall and original gate return"):quit(1);return
 if not await walk(scene,[[-1700,-2470]],"far bridge landing return"):quit(1);return
 if not check(scene.request_jump(),"ordinary return jump to bridge"):quit(1);return
 if not await walk(scene,[[-1697,-2390],[-1697,-2220],[-1697,-2120],[-1697,-1940]],"original bridge return"):quit(1);return
 if not check(scene.request_jump(),"ordinary return jump to near steps"):quit(1);return
 if not await walk(scene,[[-1697,-1875]],"near source landing200 return"):quit(1);return
 for key in ["4010","3943","3921","3962"]:
  route[key].reverse()
  if not await walk(scene,route[key],"raised path return "+key):quit(1);return
 if not await walk(scene,[[-600,-1790],[-350,-2050],[-270,-2180],[-250,-2230],[36,-2230]],"original right door return"):quit(1);return
 for i in 60:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 var fire=scene.get_node("L14FirePaths")
 check(fire.state().lowered==4 and fire.state().steps==2 and fire.state().gate==2,"solved bridge steps and gate persist")
 for id in ["371","372","384"]:check(("act2:L14_HT:trial_idol"+id) in scene.carried_collected,"three earned idols brought back")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_fire_return_earned_save.json")
 if not check(error.is_empty(),"third idol return save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_fire_return_earned_save.json").is_empty(),"third idol return reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("THREE IDOLS RETURN ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS three earned idols -> actual gate/bridge/raised paths/right door return -> save/reload")
 quit(0 if failures==0 else 1)
