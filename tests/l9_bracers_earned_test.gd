extends "res://tests/l9_opening_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var before:=Save.read_save("res://tmp/l9_white_altar_earned_save.json","lol2-restoration-dragon-preview")
 var input:=Save.read_save("res://tmp/l9_tower_saar_earned_save.json","lol2-restoration-dragon-preview")
 if not check(before.error.is_empty() and input.error.is_empty(),"actual pre/post Saar saves available"):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 var shield=scene.get_node("L9DeadBracers")
 check(scene.apply_save(before.state).is_empty(),"actual pre-Saar save load")
 check(not shield.release(),"living Saar prevents shield release")
 if not check(scene.apply_save(input.state).is_empty(),"earned Saar death save load"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_bracers_walk.json"))
 if not await walk(scene,route.points,"bracers niche"):quit(1);return
 var id:="act2:L9_DR:item55"
 scene.camera.look_at(scene.act2_items.aim_point(id),Vector3.UP)
 check(not scene.act2_items.take(id),"shield prevents early bracers pickup")
 var ray=PhysicsRayQueryParameters3D.create(scene.camera.global_position,scene.act2_items.aim_point(id),1,[scene.player.get_rid()])
 check(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"original shield plane physically occludes bracers")
 scene.camera.look_at(shield.aim,Vector3.UP)
 for i in 180:
  await physics_frame
  scene.starting_magic.select_spell("spark");scene.starting_magic.cast()
  if shield.released():break
 if not check(shield.released(),"actual Spark releases original Magic Shield312"):quit(1);return
 await physics_frame
 check(scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Spark clears original shield plane")
 scene.camera.look_at(scene.act2_items.aim_point(id),Vector3.UP)
 if not check(scene.act2_items.take(id),"earned original dead bracers55 pickup"):quit(1);return
 check(not shield.release() and not scene.act2_items.take(id),"duplicate shield/pickup refused")
 var path:="res://tmp/l9_bracers_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"bracers actual save/reload")
 shield.restore();check(shield.released() and id in scene.carried_collected,"shield release and earned bracers persist")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual pre-Saar refusal -> earned Saar save -> physical niche -> actual Spark shield312 -> original bracers55 -> save/reload; return to Cemetery pending")
 quit(0 if failures==0 else 1)
