extends "res://tests/l9_opening_earned_test.gd"
func prepare(scene: Node):
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
func walk_transport(scene: Node,controller: Node,points: Array,label: String)->bool:
 var count: int=controller.transports.size()
 for n in points.size():
  var p: Array=points[n];var goal:=Vector3(p[0],0,p[1]);var reached:=false
  for tick in 900:
   await physics_frame
   if controller.transports.size()>count:return true
   if not await fight_nearby(scene):return false
   var delta: Vector3=goal-scene.player.position;delta.y=0
   if delta.length()<(2 if n==points.size()-1 else 8):reached=true;break
   scene.move_grounded(delta.normalized(),scene.player.get_physics_process_delta_time())
  if not reached and scene.player.get_slide_collision_count()>0:
   var hit=scene.player.get_slide_collision(0);print("TRANSPORT HIT ",hit.get_collider().get_path()," ",hit.get_normal())
  if not check(reached,label+" waypoint"+str(n)+" at"+str(scene.player.position)+" goal"+str(goal)):return false
  if n%20==0:print("TRANSPORT WALK ",label," ",n," ",scene.player.position)
 return check(false,label+" did not trigger source region")
func input_save()->String:return "res://tmp/l9_bracers_earned_save.json"
func output_save()->String:return "res://tmp/l10_bracers_return_earned_save.json"
func verify_return(_scene: Node):pass
func tower_exit_points(route: Dictionary)->Array:return route.tower_exit.points
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save(input_save(),"lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned bracers load"):quit(1);return
 prepare(scene)
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_mirror_return_walk.json"))
 if not await walk_transport(scene,scene.get_node("L9Tower"),tower_exit_points(route),"Tower exit"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l9_tower_return_earned_save.json").is_empty(),"actual Tower exit save")
 if not await walk(scene,route.orb.points,"mirror door orb"):quit(1);return
 var mirrors=scene.get_node("L9Mirrors")
 scene.camera.look_at(mirrors.AIM,Vector3.UP)
 for i in 180:
  await physics_frame
  scene.starting_magic.select_spell("spark");scene.starting_magic.cast()
  if mirrors.opened():break
 if not check(mirrors.opened(),"actual Spark at original mirror-door orb1086"):quit(1);return
 for i in 180:await physics_frame
 for id in [65,66]:check(scene.progression.travel[id]==int(scene.progression.native.attributes["movable:%d"%id].angle_word),"source door100-percent travel")
 check(not mirrors.open(),"duplicate mirror activation refused")
 var doorway:="res://tmp/l9_mirror_doors_earned_save.json"
 check(scene._quicksave_unrecorded(doorway).is_empty() and scene._quickload_unrecorded(doorway).is_empty(),"open mirror doors actual save/reload")
 if not await walk_transport(scene,mirrors,route.mirror_entry.points,"mirror alcove"):quit(1);return
 check(scene.player.position.y>200,"source destination floor200 grounding")
 if not await walk(scene,route.cemetery_mirror.points,"Cemetery mirror"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"original Cemetery mirror exit fired"):quit(1);return
 var change: Dictionary=scene.progression.level_changes.back()
 if not check(change.level==10 and change.selector==2,"source Cemetery arrival2"):quit(1);return
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change)
 await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene.progression.seeds_applied.is_empty(),"no arrival seeds")
 check("act2:L9_DR:item55" in scene.carried_collected,"earned bracers survive real mirror travel")
 verify_return(scene)
 var path:=output_save()
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual Cemetery return save/reload")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned bracers -> physical Tower descent/exit -> real Spark mirror doors -> physical alcove -> original L10/2 mirror -> no-seed Cemetery save/reload")
 quit(0 if failures==0 else 1)
