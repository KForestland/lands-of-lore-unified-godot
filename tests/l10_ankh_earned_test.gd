extends "res://tests/l10_barrel_earned_test.gd"
const Ankh=preload("res://scripts/lol2/l10_ankh_state.gd")
func fight_nearby(scene: Node)->bool:
 if not check(scene.resets==0,"earned route has no resets"):return false
 return await super.fight_nearby(scene)
func input_save()->String:return "res://tmp/l10_ashes_return_earned_save.json"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save(input_save(),"lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",2)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual ashes return input"):quit(1);return
 prepare(scene)
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l9_chapel_walk.json"))
 var points: Array=route.statue.points.duplicate(true);points.reverse()
 if not await walk(scene,points,"return ashes to priest"):quit(1);return
 var priest=scene.get_node("L10Priest");scene.camera.look_at(priest.AIM,Vector3.UP)
 var before: Array=scene.carried_collected.duplicate()
 check(not priest.exchange_ashes("act2:L10_DC:item8:charged:white").ok and before==scene.carried_collected,"wrong item refusal")
 if not check(priest.speak().ok,"actual earned full urn offered through Kit"):quit(1);return
 var occupied:="res://tmp/l10_ankh_occupied_earned_save.json"
 check(scene._quicksave_unrecorded(occupied).is_empty() and scene._quickload_unrecorded(occupied).is_empty(),"occupied priest ankh save/reload")
 var full:=Ankh.act(scene.quest_state.l10_ankh,scene.carried_collected,Ankh.TRADE,"",scene.carried_collected.size())
 check(not full.ok,"occupied ankh capacity refusal")
 scene.camera.look_at(priest.AIM,Vector3.UP)
 check(priest.speak().ok,"retrieve source ankh97")
 check(not priest.speak().ok and Ankh.FULL not in scene.carried_collected and Ankh.ANKH in scene.carried_collected,"once-only urn exchange")
 check(scene._quicksave_unrecorded("res://tmp/l10_ankh_earned_save.json").is_empty(),"earned ankh checkpoint")
 var leave: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_priest_walk.json")).priest.points
 leave.reverse();leave.append([2880,-3005]);leave.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_ankh_walk.json")).points)
 if not await walk(scene,leave,"Holy Switch66"):quit(1);return
 var entry=scene.get_node("L10EmperorEntry");scene.camera.look_at(entry.SLAB_AIM,Vector3.UP)
 before=scene.carried_collected.duplicate()
 check(not entry.offer("act2:L10_DC:item8:charged:white").ok and before==scene.carried_collected,"wrong slab item refused")
 if not check(entry.offer(Ankh.ANKH).ok,"earned ankh opens outer slab66"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l10_slab_occupied_earned_save.json").is_empty() and scene._quickload_unrecorded("res://tmp/l10_slab_occupied_earned_save.json").is_empty(),"occupied slab persists")
 scene.camera.look_at(entry.SLAB_AIM,Vector3.UP)
 check(entry.offer(Ankh.ANKH).ok and Ankh.ANKH in scene.carried_collected,"retain ankh for inner tomb")
 if not await walk(scene,[[3207,-2350],[3207,-2290],[3207,-2240],[3207,-2190],[3207,-2140],[3207,-2070],[3207,-2010]],"opened Emperor entrance"):quit(1);return
 for tick in 60:
  scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time());await physics_frame
 check(scene.player.position.y< -50,"actual lower stair landing, not overlapping surface floor")
 var path:="res://tmp/l10_emperor_entry_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual entrance save/reload")
 check(entry.opened() and scene.progression.seeds_applied.is_empty(),"entry persists without seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned ashes return -> Kit priest ankh -> Kit Holy Switch66 -> actual Emperor entrance -> save/reload")
 quit(0 if failures==0 else 1)
