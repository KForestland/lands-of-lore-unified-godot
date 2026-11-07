extends "res://tests/l10_tomb_earned_test.gd"
func combat_spark()->bool:return false
func heal_threshold()->int:return 25
func reached_waypoint(scene: Node,_label: String,index: int)->void:
 if index%10==0:
  check(scene._quicksave_unrecorded("res://tmp/l9_opening_progress_earned_save.json").is_empty(),"earned walking progress save")
func run():
 var input:=Save.read_save("res://tmp/l9_pit_arrival_earned_save.json","lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Ruins arrival load"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 check(scene.set_equipped_armor("cave:captain:Burnt_Chain"),"equip earned armor through inventory action")
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_opening_walk.json"))
 if not await walk(scene,route.points,"Ruins north then west"):quit(1);return
 var path:="res://tmp/l9_opening_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty(),"earned Ruins opening save")
 check(scene._quickload_unrecorded(path).is_empty(),"earned Ruins opening reload")
 for id in ["61","68"]:check(scene.act2_creatures.state.actors[id].health==0,"opening stone enemy defeated "+id)
 check(scene.progression.level_changes.is_empty(),"no premature mirror travel")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned pit arrival -> opening stone enemies -> north-west orb approach -> actual save/reload")
 quit(0 if failures==0 else 1)
