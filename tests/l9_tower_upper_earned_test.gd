extends "res://tests/l9_opening_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240 # Same 1/60 simulated physics step, accelerated headless clock.
 var input:=Save.read_save("res://tmp/l9_white_altar_earned_save.json","lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual white altar approach load"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 var tower=scene.get_node("L9Tower");tower.restore()
 var route: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_tower_upper_walk.json"))
 for leg in route:
  if not await walk(scene,leg.route.points,"tower upper "+leg.target):quit(1);return
  if leg.target=="79":
   if not await fight_nearby(scene):quit(1);return
   check(scene.act2_creatures.state.actors["79"].health==0,"large source Saar79 defeated")
  else:
   scene.camera.look_at(tower.aims[leg.target],Vector3.UP)
   for i in 180:
    await physics_frame
    scene.starting_magic.select_spell("spark");scene.starting_magic.cast()
    if leg.target in tower.state().orbs:break
   if not check(leg.target in tower.state().orbs,"actual upper field Spark "+leg.target):quit(1);return
 var path:="res://tmp/l9_tower_saar_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"upper Saar actual save/reload")
 check(scene.act2_creatures.state.actors["79"].health==0,"Saar death persists")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned white altar approach -> actual two upper Spark fields -> live Saar79 -> save/reload; two-white supply remains separate and pending.")
 quit(0 if failures==0 else 1)
