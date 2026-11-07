extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_machines_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="473695d0556b9f34c35c57832db75d70bbeb84bf4fc25f1060284e9ca9cb7cb0","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var route:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_bedroom_approach.json"))
 if not await walk(scene,route.lower,"lower corridor return"):quit(1);return
 var passage=scene.get_node("L14LowerPassage")
 if not check(passage.choose_form(),"earned Lizard return choice"):quit(1);return
 for i in 600:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==2:break
 if not check(scene.player_form==2,"actual Lizard for upward seam"):quit(1);return
 if not await walk(scene,[[2290,-3200]],"lower floor takeoff"):quit(1);return
 if not check(scene.request_jump(),"ordinary Lizard jump up50 to lowered ritual floor"):quit(1);return
 if not await walk(scene,[[2300,-3300],[2300,-3400]],"Lizard ritual floor return"):quit(1);return
 if not check(scene.player.position.y> -5 and scene.player.position.y<10,"actual lowered floor-30"):quit(1);return
 if not check(passage.choose_form(),"return Human on ritual floor"):quit(1);return
 for i in 120:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==0:break
 if not check(scene.player_form==0,"actual Human ritual room"):quit(1);return
 if not await walk(scene,[[2300,-3500],[2350,-3610],[2315,-3660],[2220,-3750],[2174,-3795]],"return through opened hanging"):quit(1);return
 if not await walk(scene,route.upper,"red pillow bedroom"):quit(1);return
 check(scene.player.position.y>145,"original bed floor120 supports Human")
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_bedroom_approach_earned_save.json")
 if not check(error.is_empty(),"bedroom approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_bedroom_approach_earned_save.json").is_empty(),"bedroom approach reload")
 check(scene.carried_collected.count("act2:L14_HT:item65")==1 and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"same statue no seeds/recovery")
 print("BEDROOM APPROACH ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned machine statue -> actual lower return/Lizard jump -> Human ritual/hanging -> original red pillow bedroom")
 quit(0 if failures==0 else 1)
