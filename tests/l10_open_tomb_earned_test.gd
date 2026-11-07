extends "res://tests/l10_tomb_earned_test.gd"
## Produces the alternate earned input of l10_tomb_crossing_earned_test; never merges with the main route.
func combat_spark()->bool:return false
func heal_threshold()->int:return 25
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l10_gold_earned_save.json","lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual gold save"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 scene.set_equipped_armor("cave:captain:Burnt_Chain")
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_tomb_walk.json"))
 if not await walk(scene,route.door,"alternate tomb87 producer"):quit(1);return
 var tomb=scene.get_node("L10Tombs");scene.camera.look_at(tomb.aims["87"],Vector3.UP)
 if not check(tomb.offer("87","act2:L10_DC:item44:charged:yellow").ok,"Kit spends earned gold at87"):quit(1);return
 var path:="res://tmp/l10_open_tomb_supply_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual open-tomb producer save/reload")
 scene.queue_free();await process_frame
 if failures==0:print("PASS produces earned open tomb87 save for physical crossing regression; isolated alternate route, no gameplay seeds")
 quit(0 if failures==0 else 1)
