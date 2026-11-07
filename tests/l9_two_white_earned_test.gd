extends "res://tests/l9_mirror_return_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l10_two_empty_earned_save.json","lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",2)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual two-empty Cemetery save"):quit(1);return
 prepare(scene)
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_white_revisit_walk.json"))
 if not await walk(scene,route.statue.points,"Cemetery mirror statue"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l10_mirror_statue_earned_save.json").is_empty(),"actual statue approach save")
 var aim_row: Array=scene.progression.exit_objects["control:150"][0].position
 var aim:=Vector3(aim_row[0],aim_row[1],aim_row[2]);scene.camera.look_at(aim,Vector3.UP)
 var target: String=scene.progression.aimed_exit()
 print("STATUE aimed ",target," player",scene.player.position)
 if not check(target=="control:150","production source statue E target"):quit(1);return
 print("STATUE source E ",scene.progression.use_exit(target))
 if not await walk(scene,route.mirror42.points,"source mirror42"):quit(1);return
 for i in 10:await physics_frame
 if not check(not scene.progression.level_changes.is_empty(),"earned source statue mirror transition"):quit(1);return
 var change: Dictionary=scene.progression.level_changes.back()
 if not check(change.level==9 and change.selector==3,"source Ruins mirror arrival3"):quit(1);return
 scene.progression.change_scene_enabled=true;scene.progression._change_level(change);await scene_changed
 scene=current_scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 prepare(scene)
 check(scene.progression.seeds_applied.is_empty(),"no Ruins arrival seeds")
 if not await walk_transport(scene,scene.get_node("L9Mirrors"),route.outside_mirror.points,"mirror to outer Ruins"):quit(1);return
 if not await walk_transport(scene,scene.get_node("L9Tower"),route.tower_entry.points,"Tower revisit"):quit(1);return
 var tower_route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_tower_walk.json"))
 if not await walk(scene,tower_route.ground.points,"earned open ground field"):quit(1);return
 check("1090" in scene.get_node("L9Tower").state().orbs,"prior real Spark field persists")
 if not await walk(scene,tower_route.white.points,"white charger revisit"):quit(1);return
 var charger=scene.get_node("Act2Chargers")
 scene.camera.look_at(charger.globes["L9:white"].global_position,Vector3.UP)
 var before: Array=scene.carried_collected.duplicate()
 check(not charger.interact("L9:white","insert","act2:L9_DR:item55").ok and before==scene.carried_collected,"earned bracers refused without loss")
 for id in ["act2:L10_DC:item56","act2:L10_DC:item8"]:
  scene.camera.look_at(charger.globes["L9:white"].global_position,Vector3.UP)
  if not check(charger.interact("L9:white","insert",id).ok,"Kit inserts earned empty "+id):quit(1);return
  var occupied: String="res://tmp/l9_white_"+id.get_slice(":",2)+"_occupied_earned_save.json"
  check(scene._quicksave_unrecorded(occupied).is_empty() and scene._quickload_unrecorded(occupied).is_empty(),"occupied white altar save/reload")
  charger.restore();scene.camera.look_at(charger.globes["L9:white"].global_position,Vector3.UP)
  if not check(charger.interact("L9:white","retrieve").ok,"Kit retrieves original charged white "+id):quit(1);return
  check(not charger.interact("L9:white","retrieve").ok,"duplicate retrieval refused")
 var path:="res://tmp/l9_two_white_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"two white globes actual save/reload")
 for id in ["act2:L10_DC:item56:charged:white","act2:L10_DC:item8:charged:white","act2:L9_DR:item55"]:check(id in scene.carried_collected,"earned transport item persists "+id)
 check(scene.act2_creatures.state.actors["79"].health==0,"prior actual larger Saar kill persists")
 check(not scene.quest_state.l10_tombs.slots.has("87"),"no inventory/state merge with failed alternate tomb87 branch")
 scene.queue_free();await process_frame
 if failures==0:print("PASS continuous real Cemetery two-empty branch -> source E150/mirror -> Tower revisit -> Kit two whites with occupied/retrieved saves; prior Saar death/bracers retained; no seeds/merges")
 quit(0 if failures==0 else 1)
