extends "res://tests/l9_opening_earned_test.gd"
func enter_tower(scene: Node,points: Array)->bool:
 var tower=scene.get_node("L9Tower")
 for p in points:
  var goal:=Vector3(p[0],0,p[1]);var reached:=false
  for tick in 900:
   await physics_frame
   if not tower.transports.is_empty():return true
   if not await fight_nearby(scene):return false
   var delta: Vector3=goal-scene.player.position;delta.y=0
   if delta.length()<2:reached=true;break
   scene.move_grounded(delta.normalized(),scene.player.get_physics_process_delta_time())
  if not check(reached,"alcove waypoint "+str(goal)+" from "+str(scene.player.position)):return false
 return check(false,"source alcove did not transport at %s active%s region%d"%[scene.player.position,scene.starting_magic.world_active(),scene.progression.current_region])
func run():
 var input:=Save.read_save("res://tmp/l9_bridge_earned_save.json","lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned bridge load"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_tower_walk.json"))
 var tower=scene.get_node("L9Tower")
 check(scene.region_blockers_enabled and tower.blocker==scene.get_node("RegionBlockers") and scene.progression.blockers==tower.blocker,"global native/static/op197 blocker is sole physics owner")
 check(tower.visual_blocker.collision_layer==0 and not tower.visual_blocker.is_physics_processing(),"Tower visual builder cannot duplicate collision or alter player mask")
 check(tower.blocker.static_edges.size()>0 and tower.blocker.dynamic_state.size()>tower.visual_blocker.dynamic_state.size(),"full native static and dynamic pack enabled")
 var static_edge:Dictionary=tower.blocker.static_edges[0]
 var mid:=Vector3((static_edge.a[0]+static_edge.b[0])/2,float(static_edge.floor)+32,(static_edge.a[1]+static_edge.b[1])/2)
 var normal:=Vector3(static_edge.b[1]-static_edge.a[1],0,static_edge.a[0]-static_edge.b[0]).normalized()
 var wall_ray=PhysicsRayQueryParameters3D.create(mid-normal*20,mid+normal*20,512)
 check(not scene.get_world_3d().direct_space_state.intersect_ray(wall_ray).is_empty(),"native static bit0 wall has actual collision")
 if not await enter_tower(scene,route.entry.points):quit(1);return
 var landing: Array=tower.transports.back().position
 check(Vector3(landing[0],landing[1],landing[2]).is_equal_approx(Vector3(-3321,32,-1187)),"source-word alcove landing")
 check(scene._quicksave_unrecorded("res://tmp/l9_tower_entry_earned_save.json").is_empty(),"earned tower entry save")
 if not await walk(scene,route.ground.points,"ground orb"):quit(1);return
 check(tower.blocker.is_region_blocked(1171),"upstairs field initially blocks")
 var edge: Dictionary={}
 for candidate in tower.blocker.dynamic_edges:
  if int(candidate.to_dynamic)==1206 and int(candidate.from_dynamic)==-1:edge=candidate;break
 if not check(not edge.is_empty(),"source first-stair boundary exists"):quit(1);return
 var a:=Vector3(edge.inside[0],float(edge.floor)+32,edge.inside[1])
 var b:=Vector3(edge.target_inside[0],float(edge.floor)+32,edge.target_inside[1])
 var ray=PhysicsRayQueryParameters3D.create(a,b,512)
 check(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"closed field physically blocks first stairs")
 scene.camera.look_at(tower.aims["1090"],Vector3.UP)
 for i in 180:
  await physics_frame
  scene.starting_magic.select_spell("spark");scene.starting_magic.cast()
  if "1090" in tower.state().orbs:break
 if not check("1090" in tower.state().orbs,"actual Spark quenches source stair field"):quit(1);return
 await physics_frame
 check(scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Spark removes first-stair collision")
 check(not tower.light("wrong") and not tower.light("1090"),"unknown/duplicate orb refused")
 if not await walk(scene,route.white.points,"white altar upstairs"):quit(1);return
 var charger=scene.get_node("Act2Chargers")
 scene.camera.look_at(charger.globes["L9:white"].global_position,Vector3.UP)
 check(charger.reachable("L9:white"),"physically reached source white charger")
 var path:="res://tmp/l9_white_altar_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty(),"earned upstairs save")
 check(scene._quickload_unrecorded(path).is_empty(),"earned upstairs reload")
 tower.restore();check(not tower.blocker.is_region_blocked(1171),"field persists after reload")
 check(scene.progression.seeds_applied.is_empty(),"no seed adapters")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned bridge -> physical alcove -> source-word Tower transport -> actual Spark field -> upstairs white charger -> save/reload. Two-white supply/charge and upper Saar still pending.")
 quit(0 if failures==0 else 1)
