extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l12_gulch_return_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="6cb1e4ba6ad38bad11bf75e69aaf66636f16cefb42c07f2eaa4658b41cc956db","qualified gulch return input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned jungle return input"):quit(1);return
 prepare(scene)
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_larkhon_walk.json"))
 var points:Array=route.rise.duplicate(true);points.reverse()
 if not await walk(scene,points,"reverse Larkhon rise"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l8_return_eastbank_earned_save.json").is_empty(),"earned eastbank save")
 check(scene.jump_launch_speed(false)==200,"ordinary jump unchanged")
 print("TAKEOFF ",scene.player.position," speed",scene.jump_launch_speed(true))
 if not check(scene.request_jump(),"actual sprint return jump"):quit(1);return
 var airborne:=false;var landed:=false
 for i in 400:
  await physics_frame
  var d:Vector3=Vector3(5100,scene.player.position.y,1880)-scene.player.position
  scene.move_grounded(d.normalized() if d.length()>2 else Vector3.ZERO,1.0/60,true)
  if i%10==0:print("FLIGHT ",i," ",scene.player.position," v",scene.player.velocity)
  if not scene.player.is_on_floor():airborne=true
  if airborne and scene.player.is_on_floor():landed=true;break
 print("RETURN RIVER LAND ",scene.player.position)
 if not check(landed and scene.player.position.x<5150 and scene.player.position.y>20 and scene.resets==0,"first landing original upper westbank"):quit(1);return
 points=route.bank.duplicate(true);points.reverse()
 if not await walk(scene,points,"return river corridor"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l8_river_return_earned_save.json").is_empty(),"earned corridor save")
 check(scene._quickload_unrecorded("res://tmp/l8_river_return_earned_save.json").is_empty(),"earned corridor reload")
 check(scene.carried_collected.count("act2:L13_RC:dreamstone")==1 and scene.equipped_armor=="act2:L12_CM:item5","earned stone and armor retained")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds or recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned gulch return -> reverse rise -> physical uphill river jump -> original corridor/save-reload")
 quit(0 if failures==0 else 1)
