extends "res://tests/l13_upper_ruloi_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l13_upper_ruloi_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="16fa2583d9438f6bc21f40d19658f42148c6742bcff58a30f7acf734237fbed6","qualified upper return input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L13_RC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L13_RC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned upper return input"):quit(1);return
 prepare(scene)
 var points:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_second_descent_walk.json"))
 if not await walk(scene,points,"second descent approach"):quit(1);return
 var lift=scene.get_node("L13Elevator")
 scene.camera.look_at(lift.aim(),Vector3.UP);scene.starting_magic.select_spell("spark")
 if not check(scene.starting_magic.cast() and lift.state().motion.remaining<0,"actual second descent Spark"):quit(1);return
 for i in 1200:
  scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if lift.state().motion.remaining==0:break
 if not await walk(scene,[[-4860,2820],[-4839,2600],[-4839,2240]],"lower exit"):quit(1);return
 var legs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l13_lower_ruloi_walk.json"))
 for leg in legs:
  if not await walk(scene,leg.points,"lower Ruloi "+leg.actor):quit(1);return
  if leg.actor=="21":
   var spires=scene.get_node("L13Spires")
   var approaches={171:[[-5564,-2623.5],[-5464,-2519.5],[-5518,-2436.5],[-5527.75,-2435.75]],170:[[-5518,-2436.5],[-5464,-2519.5],[-5564,-2623.5],[-5698,-2649.5],[-5816,-2612],[-5889,-2528],[-5900.25,-2455.25]]}
   for spire in [171,170]:
    if not await walk(scene,approaches[spire],"Dawn gate Spire "+str(spire)):quit(1);return
    scene.camera.look_at(spires.aims[spire],Vector3.UP);scene.starting_magic.select_spell("spark")
    for tick in 1800:
     scene.starting_magic.cast();scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
     if str(spire) in spires.state().lit:break
    if not check(str(spire) in spires.state().lit,"actual Spark opens gate Spire "+str(spire)):quit(1);return
   if not await walk(scene,[[-5889,-2528],[-5816,-2612],[-5698,-2649.5],[-5631,-2636.5]],"opened Dawn gate sightline"):quit(1);return
  if not await defeat(scene,leg.actor):quit(1);return
 if not check(scene.get_node("L13Prison").all_ruloi_dead(),"all nineteen source Ruloi defeated"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l13_ruloi_cleared_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l13_ruloi_cleared_earned_save.json").is_empty(),"earned Ruloi clear save/reload")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no seed or recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned upper circuit -> actual second descent -> physical lower circuit and all nineteen Ruloi defeated/save-reload")
 quit(0 if failures==0 else 1)
