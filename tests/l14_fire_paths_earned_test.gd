extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_tilt_return_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="1d255737e19057477517b1b3b0b518144d2e84ab7ac12b2c2ff364da0b3d00b6","qualified two-idol return"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned two-idol input"):quit(1);return
 prepare(scene)
 var trials=scene.get_node("L14Trials");var fire=scene.get_node("L14FirePaths")
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_fire_paths_walk.json"))
 check(not fire.press("60").ok,"remote path button refused")
 if not await walk(scene,[[-250,-2230],[-270,-2180]],"original right NiceDoor88"):quit(1);return
 scene.camera.look_at(trials.DOORS["88"],Vector3.UP)
 if not check(trials.open_door("88").ok,"right door after second idol"):quit(1);return
 if not await walk(scene,[[-350,-2050],[-600,-1790]],"through right door to fire paths"):quit(1);return
 for pair in [["3962","60"],["3921","61"],["3943","62"]]:
  if not await walk(scene,route[pair[0]],"original raised fire path "+pair[1]):quit(1);return
  check(scene.player.position.y>185 and scene.resets==0,"button reached on raised source path")
  scene.camera.look_at(fire.BUTTONS[pair[1]],Vector3.UP)
  if pair[1]=="62":
   check(fire.state().lowered==0,"two buttons leave bridge raised")
   for z in [-2050,-2300]:
    var ray=PhysicsRayQueryParameters3D.create(Vector3(-1697,400,z),Vector3(-1697,-400,z),1)
    var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
    check(not hit.is_empty() and absf(hit.position.y-322)<0.1,"original raised bridge deck322")
   paused=true;check(not fire.press(pair[1]).ok,"paused third button refused");paused=false
  if not check(fire.press(pair[1]).ok,"distinct original path button "+pair[1]):quit(1);return
  check(not fire.press(pair[1]).ok,"duplicate button cannot lower twice")
 for i in 60:await physics_frame
 var before:float=fire.state().lowered
 paused=true
 for i in 10:await process_frame
 check(fire.state().lowered==before,"bridge lowering freezes while paused");paused=false
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_fire_bridge_moving_save.json")
 if not check(error.is_empty(),"moving bridge save: "+error):quit(1);return
 if not check(scene._quickload_unrecorded("res://tmp/l14_fire_bridge_moving_save.json").is_empty(),"moving bridge reload"):quit(1);return
 for i in 300:await physics_frame
 for z in [-2050,-2300]:
  var ray=PhysicsRayQueryParameters3D.create(Vector3(-1697,400,z),Vector3(-1697,-400,z),1)
  var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
  if not check(not hit.is_empty() and absf(hit.position.y-190)<0.1,"both original bridge decks physically190"):quit(1);return
 if not await walk(scene,route["4010"],"original raised near bridge landing200"):quit(1);return
 if not check(scene.request_jump(),"ordinary jump across near bridge gap"):quit(1);return
 if not await walk(scene,[[-1697,-1970],[-1697,-2120],[-1697,-2220],[-1697,-2390]],"physical original bridge56/57 decks"):quit(1);return
 if not check(scene.player.is_on_floor() and absf(scene.player.position.y-222)<1,"actually standing on source bridge190"):quit(1);return
 if not check(scene.request_jump(),"ordinary jump to far landing20higher"):quit(1);return
 if not await walk(scene,[[-1700,-2470]],"original far landing210"):quit(1);return
 for i in 150:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 check(fire.state().gate==2,"actual source3981 landing opens original BigGate55")
 var gate_ray=PhysicsRayQueryParameters3D.create(Vector3(-1708,250,-2600),Vector3(-1708,250,-2660),1)
 check(scene.get_world_3d().direct_space_state.intersect_ray(gate_ray).is_empty(),"original far gate physical passage opens")
 if not await walk(scene,route["4103"],"original DeathIdol384"):quit(1);return
 scene.camera.look_at(trials.PRIZES["384"],Vector3.UP)
 check(not trials.take(scene.carried_collected.size(),"384").ok,"full third statue pickup refuses")
 if not check(trials.take(64,"384").ok,"third original source idol"):quit(1);return
 check(not trials.take(64,"384").ok,"third idol cannot duplicate")
 error=scene._quicksave_unrecorded("res://tmp/l14_fire_paths_earned_save.json")
 if not check(error.is_empty(),"third idol save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_fire_paths_earned_save.json").is_empty(),"third idol reload")
 for id in ["371","372","384"]:check(("act2:L14_HT:trial_idol"+id) in scene.carried_collected,"three distinct earned trial idols")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds/teleport/recovery")
 print("THIRD IDOL ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned right door -> three original raised paths/buttons -> both original bridge parts lower/physical crossing -> source384 idol/save-reload")
 quit(0 if failures==0 else 1)
