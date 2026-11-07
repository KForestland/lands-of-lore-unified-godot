extends "res://tests/l9_chapel_earned_test.gd"
func input_save()->String:return "res://tmp/l10_emperor_remains_earned_save.json"
func statue_points(_route: Dictionary)->Array:
 var out: Array=[[3207,-1300],[3207,-1360],[3207,-1450],[3135,-1510],[3135,-1650],[3135,-1740],[3207,-1800],[3207,-1900],[3207,-1950],[3207,-2010],[3207,-2070],[3207,-2140],[3207,-2190],[3207,-2240],[3207,-2290],[3207,-2350],[3207,-2390]]
 var surface: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_emperor_walk.json")).approach.points
 surface.reverse();out.append_array(surface)
 var original: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_chapel_walk.json")).statue.points
 out.append_array(original.slice(original.size()-10))
 return out
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save(input_save(),"lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",2)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual Emperor remains Cemetery save"):quit(1);return
 prepare(scene)
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_chapel_walk.json"))
 if not await walk(scene,statue_points(route),"Cemetery mirror statue"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l10_emperor_statue_earned_save.json").is_empty(),"actual statue approach save")
 var aim_row: Array=scene.progression.exit_objects["control:150"][0].position
 var aim:=Vector3(aim_row[0],aim_row[1],aim_row[2]);scene.camera.look_at(aim,Vector3.UP)
 var target: String=scene.progression.aimed_exit()
 print("STATUE aimed ",target," player",scene.player.position)
 if not check(target=="control:150","production source statue E target"):quit(1);return
 print("STATUE source E ",scene.progression.use_exit(target))
 if not await walk(scene,route.mirror42.points,"source mirror42"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"earned source statue mirror transition"):quit(1);return
 var change: Dictionary=scene.progression.level_changes.back()
 if not check(change.level==9 and change.selector==3,"source Ruins mirror arrival3"):quit(1);return
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change);await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene.progression.seeds_applied.is_empty(),"no Ruins arrival seeds")
 check("act2:L10_DC:emperor_remains" in scene.carried_collected,"earned Emperor remains transported")
 var output:="res://tmp/l9_emperor_arrival_earned_save.json"
 check(scene._quicksave_unrecorded(output).is_empty() and scene._quickload_unrecorded(output).is_empty(),"actual Ruins remains save/reload")
 check(scene.quest_state.l10_emperor.remains and "act2:L9_DR:item55" in scene.carried_collected,"Emperor consequence and bracers transported")
 check(scene.quest_state.l10_emperor.slots["143"].occupied=="act2:L10_DC:priest_ankh","occupied inner ankh stays in Cemetery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Emperor remains -> physical Cemetery return -> source E150/mirror42 -> native Ruins arrival3 -> real save/reload; no seeds")
 quit(0 if failures==0 else 1)

