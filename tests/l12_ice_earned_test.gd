extends "res://tests/l9_chapel_earned_test.gd"
func hop(scene:Node,target:Vector2,min_height:float)->bool:
 if not check(scene.request_jump(),"ordinary Human jump"):return false
 var airborne:=false
 for i in 360:
  await physics_frame
  var delta:Vector3=Vector3(target.x,scene.player.position.y,target.y)-scene.player.position
  scene.move_grounded(delta.normalized() if delta.length()>3 else Vector3.ZERO,scene.player.get_physics_process_delta_time(),true)
  if not scene.player.is_on_floor():airborne=true
  if airborne and scene.player.is_on_floor():
   print("ICE LAND ",scene.player.position," target ",target)
   return check(scene.player.position.y>min_height and Vector2(scene.player.position.x,scene.player.position.z).distance_to(target)<90 and scene.resets==0,"original ice landing")
 return check(false,"jump did not land")
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 if not check(FileAccess.get_sha256("res://tmp/l12_gulch_qualified_save.json")=="8611777502d189ccbcf3f7d8a2d4c95a98133d16d7e77eac827d51bbb2c4f79a","qualified gulch anchor"):quit(1);return
 var input=Save.read_save("res://tmp/l12_gulch_qualified_save.json","lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned STORY036 input"):quit(1);return
 prepare(scene)
 var route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_ice_route.json"))
 var glacier=scene.get_node("L12Glacier")
 var carried:Array=scene.carried_collected.duplicate()
 var invalid=glacier.State.initial();invalid.motion.speed=49
 check(not glacier.State.validate(invalid).is_empty(),"changed native motion speed rejected")
 if not await walk(scene,route.valley,"lower valley path"):quit(1);return
 if not await walk(scene,route.entry,"glacier entry"):quit(1);return
 if not check(glacier.state().started,"physical valley entry starts logged glacier adapter"):quit(1);return
 var before:Dictionary=glacier.state().duplicate(true)
 paused=true
 for i in 12:await process_frame
 check(glacier.state()==before,"paused glacier clock");paused=false
 var mid:="res://tmp/l12_glacier_moving_earned_save.json"
 check(scene._quicksave_unrecorded(mid).is_empty() and scene._quickload_unrecorded(mid).is_empty(),"glacier motion actual save/reload")
 check(is_equal_approx(float(glacier.state().clock),float(before.clock)) and glacier.state().motion.height==before.motion.height and glacier.state().motion.remaining==before.motion.remaining and glacier.state().motion.fraction==before.motion.fraction,"saved fractional glacier motion retained")
 if not await walk(scene,route.right_wall,"glacier right wall and caves"):quit(1);return
 check(glacier.state().motion.height==-1090 and glacier.state().motion.remaining==0,"source glacier floor target reached")
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(3872,-580,-12157),Vector3(3872,-1110,-12157),1)
 var hit=scene.get_world_3d().direct_space_state.intersect_ray(ray)
 check(not hit.is_empty() and absf(hit.position.y+1090)<1,"moving collision reaches original lower floor target")
 if not await walk(scene,[[4535,-14170]],"cave lip"):quit(1);return
 for p in route.ice:
  if not await hop(scene,Vector2(p[0],p[1]),p[2]):quit(1);return
  if not await walk(scene,[[p[0],p[1]]],"ice platform center"):quit(1);return
  check(scene._quicksave_unrecorded("res://tmp/l12_ice_platform_earned_save.json").is_empty(),"earned ice checkpoint")
 if not await walk(scene,[[3615,-15030]],"last ice ledge"):quit(1);return
 if not await hop(scene,Vector2(3490,-14955),-930):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l12_ice_crossed_earned_save.json").is_empty(),"earned far cave save")
 check(scene._quickload_unrecorded("res://tmp/l12_ice_crossed_earned_save.json").is_empty(),"far cave reload")
 check(scene.carried_collected==carried and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no item merge, seeds or recovery")
 if failures==0:print("PASS earned gulch -> lower valley -> saved source-floor glacier collapse/right wall -> ice caves -> physical Human ice-platform leaps -> far cave save/reload")
 scene.queue_free();await process_frame;quit(0 if failures==0 else 1)
