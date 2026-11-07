extends "res://tests/l9_chapel_earned_test.gd"
func fight_nearby(scene:Node)->bool:
 scene.curse.advance(1.0/60) # Live controller clock while headless harness owns movement.
 return await super.fight_nearby(scene)
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var path:="res://tmp/l12_river_return_qualified_save.json"
 if not check(FileAccess.get_sha256(path)=="193c8f8ecf6395471b0b0d37bb154804d567f6beb74a04f4f4aae12ca9891568","qualified Citadel-exit input"):quit(1);return
 var input=Save.read_save(path,"lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned Citadel-exit input"):quit(1);return
 prepare(scene)
 var cave=scene.get_node("L12Crevasse")
 check(not cave.choose_form(),"remote form choice refuses")
 var points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_crevasse_approach.json"))
 if not await walk(scene,points,"glacier crevasse entrance"):quit(1);return
 scene.camera.look_at(cave.SPARK,Vector3.UP)
 scene.starting_magic.select_spell("spark")
 if not check(scene.starting_magic.cast() and cave.state().opened,"actual Spark prop436 opens original rock gate91"):quit(1);return
 paused=true;check(not cave.choose_form(),"paused form choice refuses");paused=false
 if not check(cave.choose_form(),"production contextual Lizard request"):quit(1);return
 for i in 600:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==2:break
 if not check(scene.player_form==2,"actual curse controller applies source Lizard body"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l12_crevasse_lizard_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l12_crevasse_lizard_save.json").is_empty(),"Lizard form and timer save/reload")
 points=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_crevasse_crawl.json"))
 if not await walk(scene,points,"actual Lizard crevasse crawl"):quit(1);return
 if not check(scene.player_form==2 and cave.choose_form(),"grotto production Human request"):quit(1);return
 for i in 120:
  scene.curse.advance(1.0/60);scene.move_grounded(Vector3.ZERO,1.0/60);await physics_frame
  if scene.player_form==0:break
 if not check(scene.player_form==0,"actual Human body fits grotto"):quit(1);return
 var error:String=scene._quicksave_unrecorded("res://tmp/l12_crevasse_earned_save.json")
 if not check(error.is_empty(),"grotto save: "+error):quit(1);return
 check(scene._quickload_unrecorded("res://tmp/l12_crevasse_earned_save.json").is_empty(),"grotto reload")
 check(scene.equipped_armor=="act2:L12_CM:item5" and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"earned armor/no seeds/recovery")
 print("GROTTO ",scene.player.position)
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned bank ->contextual curse request ->physical Lizard crawl ->Human grotto/save-reload")
 quit(0 if failures==0 else 1)
