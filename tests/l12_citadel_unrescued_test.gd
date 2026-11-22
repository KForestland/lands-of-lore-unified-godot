extends "res://tests/l12_citadel_earned_test.gd"
## BJ05 finding 1 (2026-11-08): a player who never cut Baccata down in L8 (l8_baccata phase 0) reaches the citadel. Native
## control 74 / group 2808 has no Baccata predicate, so the entrance must not hold such a player: Baccata simply is not in the
## ice tunnel, and E on the entrance starts the CITADEL movie as for anyone else. Input: the earned far-cave save of
## l12_citadel_earned_test with the rescue receipt set back to phase 0 (the only state edit; the validator allows phase 0).
## The level change after the movie: the skip closes the overlay, the deferred native change happens within a frame or two
## and frees the old scene, so the new scene is polled by area (scene_changed may already have fired).
func await_level(area:String)->Node:
 for i in 3000:
  await process_frame
  var next:Variant=current_scene
  if next!=null and is_instance_valid(next) and str(next.get("area_id"))==area:
   for j in 1500:
    await process_frame
    if not is_instance_valid(next) or next.ready_for_review:break
   return next
 return null
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input=Save.read_save("res://tmp/l12_charm_crossed_earned_save.json","lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 input.state.quests.l8_baccata={"version":1,"phase":0,"elapsed":0.0}
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"far-cave save without the L8 rescue"):quit(1);return
 prepare(scene)
 var citadel=scene.get_node("L12Citadel")
 var route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_citadel_walk.json"))
 if not await walk(scene,route.baccata,"Baccata ice tunnel"):quit(1);return
 scene.camera.look_at(citadel.BACCATA+Vector3.UP*50,Vector3.UP)
 for i in 3:await process_frame
 check(not citadel.state().baccata_seen and not scene.act2_creatures.state.actors["30"].present and citadel.hint.text=="","no Baccata and no prompt in the tunnel without the rescue")
 check(not citadel.talk(),"nothing to talk to")
 if not await walk(scene,route.entrance,"citadel entrance"):quit(1);return
 scene.camera.look_at(citadel.entrance_aim(),Vector3.UP)
 if not check(scene.progression.aimed_exit()=="control:74","the citadel entrance is the aimed E target"):quit(1);return
 scene.progression.change_scene_enabled=true
 scene.progression.use_exit("control:74")
 for i in 90:
  await process_frame
  if is_instance_valid(scene.video_overlay):break
 if not check(is_instance_valid(scene.video_overlay) and paused,"the entrance opens without the Baccata talk: the CITADEL movie starts"):quit(1);return
 for i in 10:await process_frame
 var e:=InputEventKey.new();e.keycode=KEY_SPACE;e.physical_keycode=KEY_SPACE;e.pressed=true
 Input.parse_input_event(e);Input.flush_buffered_events()
 scene=await await_level("L13_RC")
 if not check(scene!=null,"the L13 scene arrives after the movie"):quit(1);return
 prepare(scene)
 check(scene.area_id=="L13_RC" and scene.quest_state.l12_citadel.movie_seen and not scene.quest_state.l12_citadel.talked,"native L13 arrival with the movie receipt and no talk receipt")
 check(scene._quicksave_unrecorded("res://tmp/l13_citadel_unrescued_arrival_save.json").is_empty(),"the untalked arrival saves")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no resets or seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS no L8 rescue -> empty ice tunnel, no prompt -> citadel entrance still opens (native control 74 has no Baccata predicate) -> L13 arrival")
 quit(0 if failures==0 else 1)
