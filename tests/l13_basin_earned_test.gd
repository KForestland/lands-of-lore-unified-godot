extends "res://tests/l9_chapel_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_egg_door_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="f5450e1574da3a93ec9add223282a7c1484f85975979e01bd3de8a1fe608313c","qualified first iris input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned first iris input"):quit(1);return
 prepare(scene)
 var eggs=scene.get_node("L13Eggs")
 check(not eggs.open_eye(),"distant eye refuses")
 check(not scene.act2_items.take("act2:L13_RC:item145"),"dormant basin pickup refused")
 var route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_basin_walk.json"))
 if not await walk(scene,route.points,"eye switch"):quit(1);return
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
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned first iris -> source eye/paired irises -> actual Spark vent -> saved modern drainage -> original145/146/147 physical pickups/reload")
 quit(0 if failures==0 else 1)
