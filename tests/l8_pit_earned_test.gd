extends "res://tests/l10_tomb_earned_test.gd"
func run():
 var input:=Save.read_save("res://tmp/l8_pit_rim_earned_save.json","lol2-restoration-darker-jungle")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",2)
 var scene=load("res://scenes/lol2/darker_jungle.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned pit rim load"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 var descent: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_pit_descent_walk.json"))
 if not await walk(scene,descent.points,"pit exit rim"):quit(1);return
 if not await walk(scene,[descent.pit],"pit descent"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"source pit exit fires"):quit(1);return
 var change: Dictionary=scene.progression.level_changes.back()
 if not check(change.level==9 and change.selector==1,"pit takes source Ruins arrival1"):quit(1);return
 check(scene.progression.seeds_applied.is_empty(),"no Jungle seeds")
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change)
 await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 check(scene.progression.seeds_applied.is_empty(),"no Ruins seeds")
 check("act2:L10_DC:item44:charged:yellow" in scene.carried_collected,"earned gold at Ruins")
 var path:="res://tmp/l9_pit_arrival_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty(),"earned Ruins arrival save")
 check(scene._quickload_unrecorded(path).is_empty(),"earned Ruins arrival reload")
 print("RUINS ARRIVAL ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Jungle pit descent -> native Ruins arrival1 -> real save/reload with earned gold")
 quit(0 if failures==0 else 1)
