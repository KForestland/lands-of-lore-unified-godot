extends "res://tests/l12_ice_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 if not check(FileAccess.get_sha256("res://tmp/l12_gulch_qualified_save.json")=="8611777502d189ccbcf3f7d8a2d4c95a98133d16d7e77eac827d51bbb2c4f79a","qualified gulch anchor"):quit(1);return
 var input=Save.read_save("res://tmp/l12_gulch_qualified_save.json","lol2-restoration-map-L12_CM")
 if not check(input.error.is_empty(),input.error):quit(1);return
 var scene=load("res://scenes/lol2/maps/L12_CM.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned STORY036 input"):quit(1);return
 prepare(scene)
 var citadel=scene.get_node("L12Citadel")
 var route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_ice_route.json"))
 var glacier=scene.get_node("L12Glacier")
 var carried:Array=scene.carried_collected.duplicate()
 check(not citadel.search_body().ok and scene.carried_collected==carried,"remote body search refused without reward")
 var invalid=glacier.State.initial();invalid.motion.speed=49
 check(not glacier.State.validate(invalid).is_empty(),"changed native motion speed rejected")
 if not await walk(scene,route.valley,"lower valley path"):quit(1);return
 if not await walk(scene,route.entry,"glacier entry"):quit(1);return
 if not check(glacier.state().started,"physical valley entry starts logged glacier adapter"):quit(1);return
 var before:Dictionary=glacier.state().duplicate(true)
 paused=true
 for i in 12:await process_frame
 check(glacier.state()==before,"paused glacier clock");paused=false
 var mid:="res://tmp/l12_citadel_glacier_earned_save.json"
 check(scene._quicksave_unrecorded(mid).is_empty() and scene._quickload_unrecorded(mid).is_empty(),"glacier motion actual save/reload")
 check(is_equal_approx(float(glacier.state().clock),float(before.clock)) and glacier.state().motion.height==before.motion.height and glacier.state().motion.remaining==before.motion.remaining and glacier.state().motion.fraction==before.motion.fraction,"saved fractional glacier motion retained")
 if not await walk(scene,route.right_wall,"glacier right wall and caves"):quit(1);return
 check(glacier.state().motion.height==-1090 and glacier.state().motion.remaining==0,"source glacier floor target reached")
 var ray:=PhysicsRayQueryParameters3D.create(Vector3(3872,-580,-12157),Vector3(3872,-1110,-12157),1)
 var hit=scene.get_world_3d().direct_space_state.intersect_ray(ray)
 check(not hit.is_empty() and absf(hit.position.y+1090)<1,"moving collision reaches original lower floor target")
 scene.camera.look_at(citadel.BODY+Vector3.UP*12,Vector3.UP)
 var result:Dictionary=citadel.search_body()
 if not check(result.ok,str(result)):quit(1);return
 check(not citadel.search_body().ok,"Kenneth cannot grant duplicate picture")
 if not check(scene.open_inventory(),"open picture inventory"):quit(1);return
 var selected:=false
 for i in scene.inventory.item_list.item_count:
  if scene.inventory.item_list.get_item_metadata(i)==citadel.State.PICTURE:scene.inventory.select_item(i);selected=true;break
 if not check(selected and scene.inventory.use_button.visible,"picture has ready-to-throw action"):quit(1);return
 scene.inventory.use_selected_item();await process_frame
 scene.camera.look_at(scene.player.position+Vector3(25,-30,25),Vector3.UP)
 var inventory:Array=scene.carried_collected.duplicate()
 check(citadel.State.impact(citadel.state(),inventory,citadel.State.PICTURE,inventory.size()).ok,"full valid inventory trades picture for charm in vacated slot")
 check(not citadel.State.impact(citadel.state(),inventory,citadel.State.PICTURE,inventory.size()-1).ok,"invalid capacity refuses conversion atomically")
 check(not citadel.throw_picture("wrong").ok and scene.carried_collected==inventory,"wrong item refused without loss")
 paused=true;check(not citadel.throw_picture(citadel.State.PICTURE).ok,"paused picture throw refused");paused=false
 result=citadel.throw_picture(citadel.State.PICTURE)
 if not check(result.ok,str(result)):quit(1);return
 check(citadel.State.CHARM in scene.carried_collected and citadel.State.PICTURE not in scene.carried_collected,"actual picture becomes original Charm90")
 check(not citadel.throw_picture(citadel.State.PICTURE).ok,"no repeated picture conversion")
 carried=scene.carried_collected.duplicate()
 check(scene._quicksave_unrecorded("res://tmp/l12_kenneth_charm_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l12_kenneth_charm_earned_save.json").is_empty(),"earned charm save/reload")
 if not await walk(scene,[[4535,-14170]],"cave lip"):quit(1);return
 for p in route.ice:
  if not await hop(scene,Vector2(p[0],p[1]),p[2]):quit(1);return
  if not await walk(scene,[[p[0],p[1]]],"ice platform center"):quit(1);return
  check(scene._quicksave_unrecorded("res://tmp/l12_citadel_ice_earned_save.json").is_empty(),"earned ice checkpoint")
 if not await walk(scene,[[3615,-15030]],"last ice ledge"):quit(1);return
 if not await hop(scene,Vector2(3490,-14955),-930):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l12_charm_crossed_earned_save.json").is_empty(),"earned far cave save")
 check(scene._quickload_unrecorded("res://tmp/l12_charm_crossed_earned_save.json").is_empty(),"far cave reload")
 check(scene.carried_collected==carried and scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no item merge, seeds or recovery")
 var walk_route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_citadel_walk.json"))
 if not await walk(scene,walk_route.baccata,"Baccata ice tunnel"):quit(1);return
 scene.camera.look_at(citadel.BACCATA+Vector3.UP*50,Vector3.UP)
 if not check(citadel.talk(),"earned rescued Baccata meeting"):quit(1);return
 check(not citadel.talk(),"Baccata summary once-only")
 check(scene._quicksave_unrecorded("res://tmp/l12_baccata_earned_save.json").is_empty(),"Baccata saved receipt")
 if not await walk(scene,walk_route.entrance,"citadel entrance"):quit(1);return
 var position:Array=scene.progression.exit_objects["control:74"][0].position
 scene.camera.look_at(citadel.entrance_aim(),Vector3.UP)
 if not check(scene.progression.aimed_exit()=="control:74","actual source citadel entrance aim"):quit(1);return
 scene.progression.change_scene_enabled=true
 scene.progression.use_exit("control:74")
 for i in 90:
  await process_frame
  if is_instance_valid(scene.video_overlay):break
 if not check(is_instance_valid(scene.video_overlay) and paused,"original movie13 starts before native transition"):quit(1);return
 check(not scene._quicksave_unrecorded("res://tmp/l12_during_movie_forbidden_save.json").is_empty(),"movie overlay blocks saves")
 for i in 15:await process_frame
 check(scene.video_overlay.video.is_playing(),"original citadel movie is playing")
 # Let all591 original frames finish before the native handoff.
 await scene_changed;scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene.area_id=="L13_RC" and scene.quest_state.l12_citadel.movie_seen,"native L13 arrival after movie")
 check(preload("res://scripts/lol2/l12_citadel_state.gd").CHARM in scene.carried_collected,"earned charm reaches citadel")
 check(scene._quicksave_unrecorded("res://tmp/l13_citadel_arrival_earned_save.json").is_empty(),"actual citadel arrival save")
 check(scene.resets==0 and scene.progression.seeds_applied.is_empty(),"no resets or seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual Kenneth search/Kit ground-impact charm -> original ice crossing -> rescued Baccata summary -> original CITADEL movie13 -> native L13/1 earned arrival")
 quit(0 if failures==0 else 1)
