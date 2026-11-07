extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_hopper_corpses_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="1c679ec79729de8e14a9aff9a7f8b12aa5ec2e279c12a157287fadd7e3b36b6d","qualified three-idol return"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned three-idol input"):quit(1);return
 prepare(scene)
 var puzzle=scene.get_node("L14HopperPlatform")
 check(not puzzle.place(puzzle.item("91")).ok,"remote body placement refuses")
 if not await walk(scene,[[40,6320],[40,6150],[-30,6070]],"five earned bodies return along gallery"):quit(1);return
 if not check(scene.request_jump(),"actual return jump onto source side ledge"):quit(1);return
 if not await walk(scene,[[-47,5935]],"side-ledge placement without stepping on platform"):quit(1);return
 check(scene.player.position.x< -35 and not puzzle.state().stepped,"player remains off platform")
 for id in puzzle.IDS:
  scene.camera.look_at(puzzle.POINT,Vector3.UP)
  var before=scene.carried_collected.duplicate()
  check(not puzzle.place("wrong").ok,"wrong platform item refuses")
  check(not puzzle.place(puzzle.item(id),scene.carried_collected.size()).ok,"full placement refuses")
  paused=true;check(not puzzle.place(puzzle.item(id)).ok,"paused body placement refuses");paused=false
  check(before==scene.carried_collected,"refusals preserve five earned bodies")
  if not check(puzzle.place(puzzle.item(id)).ok,"Kit places distinct body "+id):quit(1);return
  check(not puzzle.place(puzzle.item(id)).ok,"body cannot count twice")
  check(not puzzle.state().stepped and puzzle.state().lowered==0,"bodies alone do not launch platform")
 if not await walk(scene,[[5,5920]],"actual Human step onto five-body platform"):quit(1);return
 check(puzzle.state().stepped and puzzle.state().lowered>0 and puzzle.state().lowered<4,"actual player weight starts descent")
 var moving:float=puzzle.state().lowered
 paused=true
 for i in 8:await process_frame
 check(puzzle.state().lowered==moving,"pressure lift pauses");paused=false
 var err:String=scene._quicksave_unrecorded("res://tmp/l14_hopper_lift_moving_save.json")
 if not check(err.is_empty(),"moving pressure lift save: "+err):quit(1);return
 if not check(scene._quickload_unrecorded("res://tmp/l14_hopper_lift_moving_save.json").is_empty(),"moving pressure lift reload"):quit(1);return
 for i in 360:scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
 check(puzzle.state().lowered==4 and scene.player.is_on_floor() and absf(scene.player.position.y+38)<2,"actual physical ride to source-word lower floor-70")
 var ray=PhysicsRayQueryParameters3D.create(Vector3(41,0,5919),Vector3(41,-150,5919),1)
 var hit:Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(ray)
 check(not hit.is_empty() and absf(hit.position.y+70)<0.1,"original pressure floor collision lowered")
 for id in puzzle.IDS:check(puzzle.item(id) not in scene.carried_collected and puzzle.Kit.slot(puzzle.state(),id).committed,"five bodies remain in platform slots")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_hopper_platform_earned_save.json")
 if not check(error.is_empty(),"flute approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_hopper_platform_earned_save.json").is_empty(),"flute approach reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeded inventory or recovery")
 print("FLUTE APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS five real hopper corpses -> actual carry return/side placement -> player weight -> physical pressure-lift ride/save-reload")
 quit(0 if failures==0 else 1)
