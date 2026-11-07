extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_library_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="7085b56be637b4e2372b0279ad8018b276238233d9f9aa34f2ce705820e413ce","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var library=scene.get_node("L14Library")
 var route:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_library_exit_walk.json"))
 if not await walk(scene,route,"return to library wall button148"):quit(1);return
 scene.camera.look_at(library.BUTTONS[148],Vector3.UP)
 if not check(library.interact(148).ok,"press original library exit148"):quit(1);return
 for i in 160:await physics_frame
 var passage=scene.get_node("L14LowerPassage")
 if not check(passage.choose_form(),"earned Lizard return through steep corridor"):quit(1);return
 for i in 600:
  if scene.curse.state.remaining<0.15 and scene.player.is_on_floor():scene.request_jump() # Actual hop gives the flat Lizard cylinder clearance above the sloped floor.
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==2:break
 if not check(scene.player_form==2,"actual Lizard exit body"):quit(1);return
 if not await walk(scene,[[1735,-5041.5],[1845,-5088]],"opened original library exit"):quit(1);return
 if not check(scene.request_jump(),"ordinary jump40 from lowered exit floor to outer floor"):quit(1);return
 if not await walk(scene,[[1845,-5163],[1847,-5198]],"exit floor40 upward seam"):quit(1);return
 if not check(passage.choose_form(),"Human after library exit"):quit(1);return
 for i in 120:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==0:break
 if not check(scene.player_form==0,"Human outer room"):quit(1);return
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_library_exit_earned_save.json")
 if not check(error.is_empty(),"library exit save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_library_exit_earned_save.json").is_empty(),"library exit reload")
 check(scene.carried_collected.count("act2:L14_HT:item65")==1 and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"same statue no seeds/recovery")
 print("LIBRARY EXIT ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned library -> exit148 -> actual Lizard corridor return/Human/save-reload")
 quit(0 if failures==0 else 1)
