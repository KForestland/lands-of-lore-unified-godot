extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_citadel_arrival_regression_anchor.json"
 if not check(FileAccess.get_sha256(path)=="21db5d3f9596650ad96df594e103eca6eb79dea299d91e585e610b146622b948","qualified citadel input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual citadel arrival"):quit(1);return
 prepare(scene)
 var door=scene.get_node("L13EggDoor")
 var route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_egg_door_walk.json"))
 if not await walk(scene,route.points,"first egg globe"):quit(1);return
 var gate:=PhysicsRayQueryParameters3D.create(Vector3(-3260,32,4950),Vector3(-3260,32,4850),1<<9)
 check(not scene.get_world_3d().direct_space_state.intersect_ray(gate).is_empty(),"original region1226 blocks closed passage")
 scene.camera.look_at(door.AIM,Vector3.UP)
 paused=true;check(not door.light(1),"paused globe refuses");paused=false
 check(not door.light(5),"non-Spark aura cannot directly open globe")
 for i in 180:
  await physics_frame
  if scene.starting_magic.magic_state().cooldown<=0:break
 scene.starting_magic.select_spell("spark")
 var mana:int=scene.starting_magic.magic_state().player.mana
 if not check(scene.starting_magic.cast(),"production Spark cast"):quit(1);return
 await physics_frame
 if not check(door.state().opened,"actual Spark ray opens original egg door"):quit(1);return
 check(scene.starting_magic.magic_state().player.mana==mana-1,"single mana debit")
 check(scene.get_world_3d().direct_space_state.intersect_ray(gate).is_empty(),"original passage collision clears")
 var saved:="res://tmp/l13_egg_globe_earned_save.json"
 check(scene._quicksave_unrecorded(saved).is_empty() and scene._quickload_unrecorded(saved).is_empty(),"globe receipt save/reload")
 if not await walk(scene,[[-3320,5500],[-3320,5200],[-3260,5000],[-3260,4800]],"open egg doorway"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l13_egg_door_earned_save.json").is_empty(),"physical egg-door crossing saved")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds or recovery")
 var eggs=scene.get_node("L13Eggs")
 check(not eggs.open_eye(),"distant eye refuses")
 check(not scene.act2_items.take("act2:L13_RC:item145"),"dormant basin pickup refused")
 var basin_route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_basin_walk.json"))
 if not await walk(scene,basin_route.points,"eye switch"):quit(1);return
 scene.camera.look_at(eggs.EYE,Vector3.UP)
 paused=true;check(not eggs.open_eye(),"paused eye refuses");paused=false
 if not check(eggs.open_eye(),"source eye switch opens paired irises"):quit(1);return
 check(not eggs.open_eye(),"eye switch once-only")
 if not await walk(scene,[[-3100,4210],[-2900,4210],[-2650,4210],[-2460,4210]],"egg chamber"):quit(1);return
 scene.camera.look_at(eggs.VENT,Vector3.UP);scene.starting_magic.select_spell("spark")
 if not check(scene.starting_magic.cast(),"production Spark strikes central fixture"):quit(1);return
 if not check(eggs.state().vent_broken,"original vent target destroyed"):quit(1);return
 check(not scene.act2_items.take("act2:L13_RC:item145"),"loot waits for completed drainage")
 var elapsed:float=eggs.state().drain;paused=true
 for i in 12:await process_frame
 check(is_equal_approx(eggs.state().drain,elapsed),"paused drain clock");paused=false
 check(scene._quicksave_unrecorded("res://tmp/l13_basin_draining_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_basin_draining_earned_save.json").is_empty(),"draining save/reload")
 for i in 240:
  await physics_frame
  if eggs.state().drain>=eggs.DRAIN_TIME:break
 check(eggs.state().drain==eggs.DRAIN_TIME,"modern drainage completes")
 for n in [145,146,147]:
  var id:="act2:L13_RC:item%d"%n
  var p:Vector3=scene.act2_items.aim_point(id)
  if not await walk(scene,[[p.x,p.z+55]],"exposed basin loot"):quit(1);return
  scene.camera.look_at(p,Vector3.UP)
  if not check(scene.act2_items.take(id),"take original basin placement%d"%n):quit(1);return
  check(not scene.act2_items.take(id),"no duplicate basin reward")
 check(scene._quicksave_unrecorded("res://tmp/l13_basin_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_basin_earned_save.json").is_empty(),"actual basin loot save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds or recovery")
 var lift=scene.get_node("L13Elevator")
 check(not lift.activate(2),"wrong Spark level refuses")
 var lift_route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_elevator_walk.json"))
 if not await walk(scene,lift_route.points,"elevator approach"):quit(1);return
 scene.camera.look_at(lift.aim(),Vector3.UP)
 paused=true;check(not lift.activate(),"paused elevator refuses");paused=false
 scene.starting_magic.select_spell("spark")
 if not check(scene.starting_magic.cast() and lift.state().started,"production Spark starts elevator"):quit(1);return
 check(not lift.activate(),"duplicate activation refuses")
 var height:float=lift.state().motion.height;paused=true
 for i in 12:await process_frame
 check(lift.state().motion.height==height,"paused elevator clock");paused=false
 for i in 120:
  scene.move_grounded(Vector3.ZERO,1.0/60.0);await physics_frame
 check(scene._quicksave_unrecorded("res://tmp/l13_elevator_moving_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_elevator_moving_earned_save.json").is_empty(),"moving elevator save/reload")
 for i in 900:
  scene.move_grounded(Vector3.ZERO,1.0/60.0);await physics_frame
  if lift.state().motion.remaining==0:break
 check(lift.state().motion.height==-1040,"source lower endpoint reached")
 check(absf(scene.player.position.y+1008)<8,"player physically rides descent")
 if not await walk(scene,[[-4860,3090],[-4860,2820],[-4839,2600],[-4839,2240]],"lower landing gate"):quit(1);return
 print("ELEVATOR_END ",scene.player.position," motion ",lift.state())
 check(scene._quicksave_unrecorded("res://tmp/l13_elevator_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_elevator_earned_save.json").is_empty(),"actual lower elevator save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seeds or recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS full STORY039 earned citadel arrival -> first iris -> eye -> vent/drain -> three original basin items -> physical Spark elevator descent/save-reload")
 quit(0 if failures==0 else 1)
