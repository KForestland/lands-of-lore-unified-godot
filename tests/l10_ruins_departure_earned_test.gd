extends "res://tests/l10_tomb_earned_test.gd"
func prepare(scene: Node)->void:
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
func run():
 var input:=Save.read_save("res://tmp/l10_gold_earned_save.json","lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned gold load"):quit(1);return
 prepare(scene)
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ruins_pit_earned_walk.json"))
 if not await walk(scene,route.cemetery.points,"return to Jungle"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"source cemetery exit fires"):quit(1);return
 var change: Dictionary=scene.progression.level_changes.back()
 if not check(change.level==8 and change.selector==2,"source Jungle arrival2"):quit(1);return
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change)
 await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene.progression.seeds_applied.is_empty(),"no Jungle arrival seeds")
 check("act2:L10_DC:item44:charged:yellow" in scene.carried_collected,"earned gold globe transported")
 check(scene._quicksave_unrecorded("res://tmp/l8_gold_return_earned_save.json").is_empty(),"earned Jungle return save")
 if not await walk(scene,route.jungle.points,"Jungle pit rim"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l8_pit_rim_earned_save.json").is_empty(),"earned pit rim save")
 print("PASS earned gold charge -> cemetery exit -> Jungle pit rim; pit descent pending")
 scene.queue_free();await process_frame
 quit(0 if failures==0 else 1)
