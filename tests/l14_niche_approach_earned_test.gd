extends "res://tests/l12_logs_approach_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l14_library_exit_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="c93cdc09fe331b47f739d38b453275c04cd813b3fc09a07c1eeb148cc3234a07","qualified Temple arrival"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L14_HT")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L14_HT.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Temple input"):quit(1);return
 prepare(scene)
 for i in 5:await physics_frame
 var route:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_niche_approach.json"))
 if not await walk(scene,route.slice(0,43),"original statue niche approach"):quit(1);return
 var passage=scene.get_node("L14LowerPassage")
 if not check(passage.choose_form(),"earned Lizard low niche corridor"):quit(1);return
 for i in 600:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==2:break
 if not check(scene.player_form==2,"actual low corridor Lizard"):quit(1);return
 if not await walk(scene,route.slice(43,52),"low header and original niche floor"):quit(1);return
 if not check(scene.player.position.y<20,"actual niche floor-20 below overlapping lower ceilings"):quit(1);return
 if not check(passage.choose_form(),"Human in statue room"):quit(1);return
 for i in 120:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==0:break
 if not check(scene.player_form==0,"actual Human niche approach"):quit(1);return
 if not await walk(scene,route.slice(52),"original empty statue niche"):quit(1);return
 print("NICHE APPROACH ",scene.player.position)
 var error:String=scene._quicksave_unrecorded("res://tmp/l14_niche_approach_earned_save.json")
 if not check(error.is_empty(),"niche approach save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l14_niche_approach_earned_save.json").is_empty(),"niche approach reload")
 check(scene.carried_collected.count("act2:L14_HT:item65")==1 and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"same statue no seeds/recovery")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned library exit -> actual original statue niche approach/save-reload")
 quit(0 if failures==0 else 1)
