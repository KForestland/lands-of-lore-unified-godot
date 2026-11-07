extends "res://tests/l9_chapel_earned_test.gd"
func combat_candidate(_scene: Node,id: String)->bool:return id!="76"
func reached_waypoint(_scene: Node,_label: String,_index: int)->void:pass
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l9_statue_offering_earned_save.json","lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual bowl save"):quit(1);return
 prepare(scene)
 var walker=scene.get_node("L9StatueWalk")
 for i in 2:await physics_frame
 check(not scene.get_node("RegionBlockers").is_region_blocked(3565),"earned offering restores original group12766 passage bit0")
 check(scene._quickload_unrecorded("res://tmp/l9_statue_question_earned_save.json").is_empty(),"load earned pre-offering visit")
 for i in 2:await physics_frame
 check(scene.get_node("RegionBlockers").is_region_blocked(3565),"older earned save restores closed passage")
 check(scene.apply_save(input.state).is_empty(),"restore earned committed bowl save")
 for i in 2:await physics_frame
 check(not scene.get_node("RegionBlockers").is_region_blocked(3565),"committed bowl reopens passage after older save")
 for index in 11:
  for i in 9000:
   await physics_frame
   if int(walker.state().marker)>index:break
  if not check(int(walker.state().marker)>index,"statue physically reached original marker "+str(index)):quit(1);return
  if not await walk(scene,[walker.source.path.points[index].position],"follow original actor76 path0"):quit(1);return
  check(scene.resets==0 and scene.player_form==0,"physical Human follow without recovery")
  if index==5:
   var path:="res://tmp/l9_statue_midwalk_earned_save.json"
   var pose: Vector3=walker.population.bodies["76"].position
   check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"moving statue saves and restores")
   check(walker.population.bodies["76"].position.distance_to(pose)<0.01,"statue position survives reload")
 if not await walk(scene,[[4111,-9959]],"original worm room corridor"):quit(1);return
 for i in 9000:
  await physics_frame
  if walker.movie_active:break
 if not walker.movie_active:
  if not await walk(scene,[[4200,-10100]],"original fight trigger"):quit(1);return
  for i in 300:await process_frame
 if not check(walker.movie_active and paused,"original movie54 started after physical statue arrival as Human"):quit(1);return
 print("MOVIE54 original fight playing")
 for i in 200000:
  await process_frame
  if walker.state().fight_done:break
 if not check(walker.state().fight_done and not paused,"original fight finishes and returns to corridor"):quit(1);return
 check(scene.player.position.distance_to(Vector3(4111,12,-9959))<0.1,"source opcode18 corridor return")
 check(not scene.act2_creatures.state.actors["76"].present,"source statue unlink after fight")
 check("act2:L9_DR:item55" in scene.carried_collected,"earned bracers retained")
 check(scene.progression.seeds_applied.is_empty() and scene.resets==0,"no seeds or recovery")
 var path:="res://tmp/l9_statue_fight_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"earned fight corridor save/reload")
 check(not walker.begin_fight(),"fight cannot repeat after reload")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned bowl -> original physical statue path0 follow/midwalk reload -> original movie54 -> source corridor -> save/reload; Dampen spell not qualified by this slice")
 quit(0 if failures==0 else 1)
