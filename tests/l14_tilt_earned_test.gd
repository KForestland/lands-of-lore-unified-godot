extends "res://tests/l12_logs_approach_earned_test.gd"
# Several original hoppers converge at the settled floor; allow real melee for the whole group.
func combat_tick_budget()->int:return 18000
func walk(scene:Node,points:Array,label:String)->bool:
 var ok:bool=await super.walk(scene,points,label)
 if not ok:
  for i in scene.player.get_slide_collision_count():
   var hit:KinematicCollision3D=scene.player.get_slide_collision(i)
   print("TILT CONTACT ",hit.get_collider().get_path()," ",hit.get_position()," ",hit.get_normal())
  print("TILT FORM ",scene.player_form," velocity ",scene.player.velocity)
 return ok
func ride_high(scene:Node)->bool:
 for i in 2400:
  scene.move_grounded(Vector3.ZERO,1.0/60);scene.curse.advance(1.0/60);await physics_frame
  if scene.player.is_on_floor() and scene.player.position.y>360:return true
 return check(false,"actual high-side ride at "+str(scene.player.position))
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_ledge_return_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="4b5ef9ae27bcdfb14811df37100b97908c11b7eab864ed34a34cd70ad00de21b","qualified earned first idol return"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned left-idol input"):quit(1);return
 prepare(scene)
 var tilt=scene.get_node("L14Tilt");var trials=scene.get_node("L14Trials")
 for i in 2:await physics_frame
 var corridor_ray=PhysicsRayQueryParameters3D.create(Vector3(32,200,-1450),Vector3(32,350,-1450),1)
 var corridor_hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(corridor_ray)
 check(not corridor_hit.is_empty() and absf(corridor_hit.position.y-290)<0.1,"upper corridor ceiling remains290 without lower220 overlap")
 var lower_ray=PhysicsRayQueryParameters3D.create(Vector3(180,200,-1590),Vector3(180,350,-1590),1)
 var lower_hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(lower_ray)
 check(not lower_hit.is_empty() and lower_hit.position.y<240,"lower ceiling retained outside upper corridor footprint")
 check(not tilt.press("145").ok,"remote high button refuses")
 if not await walk(scene,[[32,-2170]],"original middle NiceDoor89"):quit(1);return
 scene.camera.look_at(trials.DOORS["89"],Vector3.UP)
 if not check(trials.open_door("89").ok,"middle door after first idol"):quit(1);return
 if not await walk(scene,[[32,-2000],[32,-1600],[32,-1450],[140,-1320],[300,-1230],[360,-1100]],"enter original right floor2133"):quit(1);return
 scene.camera.look_at(tilt.BUTTONS["145"],Vector3.UP)
 check(not tilt.press("145").ok,"high button remains unreachable from low floor")
 var before:float=tilt.state().elapsed
 paused=true
 for i in 10:await process_frame
 check(tilt.state().elapsed==before,"floor phase freezes while paused");paused=false
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_tilt_moving_save.json")
 if not check(error.is_empty(),"moving tilt save: "+error):quit(1);return
 if not check(scene._quickload_unrecorded("res://tmp/l14_tilt_moving_save.json").is_empty(),"moving tilt reload"):quit(1);return
 if not await ride_high(scene):quit(1);return
 if not await walk(scene,[[360,-944]],"right near high button145"):quit(1);return
 scene.camera.look_at(tilt.BUTTONS["145"],Vector3.UP)
 if not check(tilt.press("145").ok,"actual high-side first button"):quit(1);return
 check(not tilt.press("145").ok,"same button cannot advance count twice")
 if not await walk(scene,[[360,356]],"right far high button144"):quit(1);return
 scene.camera.look_at(tilt.BUTTONS["144"],Vector3.UP)
 if not check(tilt.press("144").ok,"actual second right button"):quit(1);return
 var ray=PhysicsRayQueryParameters3D.create(Vector3(0,220,930),Vector3(0,220,1210),1)
 check(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"two buttons leave far barrier closed")
 if not await walk(scene,[[-330,327]],"cross to original left floor2132"):quit(1);return
 if not await ride_high(scene):quit(1);return
 scene.camera.look_at(tilt.BUTTONS["143"],Vector3.UP)
 if not check(tilt.press("143").ok,"actual first left button"):quit(1);return
 if not await walk(scene,[[-330,-973]],"left near high button142"):quit(1);return
 scene.camera.look_at(tilt.BUTTONS["142"],Vector3.UP)
 paused=true;check(not tilt.press("142").ok,"paused final button refused");paused=false
 if not check(tilt.press("142").ok,"four distinct high buttons"):quit(1);return
 for i in 180:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 check(tilt.state().settled==2,"floors level and passage lowered")
 check(scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"original far passage collision opens")
 if not await walk(scene,[[0,-973],[0,612],[0,900],[0,1100],[0,1250],[0,1400]],"actual far barrier2291 crossing"):quit(1);return
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_tilt_walk.json"))
 if not await walk(scene,route.prize,"original middle statue372"):quit(1);return
 scene.camera.look_at(trials.PRIZES["372"],Vector3.UP)
 check(not trials.take(scene.carried_collected.size(),"372").ok,"full middle statue pickup refuses")
 if not check(trials.take(64,"372").ok,"original middle Jkar idol"):quit(1);return
 check(not trials.take(64,"372").ok,"middle idol cannot duplicate")
 error=scene._quicksave_unrecorded("res://tmp/l14_tilt_earned_save.json")
 if not check(error.is_empty(),"middle idol save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_tilt_earned_save.json").is_empty(),"middle idol reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty() and trials.IDOL in scene.carried_collected,"first idol retained, no seeds/recovery")
 print("MIDDLE IDOL ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned middle door -> opposite source floor rides/four high buttons -> original far passage -> original372 idol/save-reload")
 quit(0 if failures==0 else 1)
