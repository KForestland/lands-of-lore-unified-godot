extends "res://tests/l10_blue_earned_test.gd"
func fight_nearby(scene: Node)->bool:
 if not check(scene.resets==0,"earned supply route has no resets"):return false
 return await super.fight_nearby(scene)
func input_save()->String:return "res://tmp/l10_emperor_entry_earned_save.json"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save(input_save(),"lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",2)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual Emperor entrance input"):quit(1);return
 prepare(scene)
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_emperor_supply_walk.json"))
 var blue: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_blue_walk.json"))
 if not await walk(scene,[[3207,-2070],[3207,-2140],[3207,-2190],[3207,-2240],[3207,-2290],[3207,-2350],[3207,-2390]],"leave Emperor stairs"):quit(1);return
 if not await walk(scene,route.surface_to_breach.points,"return to original breach"):quit(1);return
 if not await walk(scene,[[-1428,-3005],[-1435,-3120],[-1475,-3160],[-1490,-3250],[-1450,-3300],[-1435,-3350]],"original opened breach"):quit(1);return
 for tick in 120:
  scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time());await physics_frame
 check(absf(scene.player.position.y+58)<3,"earned north catacomb landing")
 if not await walk(scene,blue.blue.points,"original empty43"):quit(1);return
 var id:="act2:L10_DC:item43";scene.camera.look_at(scene.act2_items.aim_point(id),Vector3.UP)
 if not check(scene.act2_items.take(id),"actual source empty43 pickup"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l10_emperor_empty43_earned_save.json").is_empty(),"earned empty43 checkpoint")
 if not await walk(scene,blue.stairs.points,"reverse northern stairs"):quit(1);return
 if not await walk(scene,blue.fence74.points,"fence74 high approach"):quit(1);return
 if not await jump_fence(scene,74):quit(1);return
 if not await walk(scene,blue.fence174.points,"fence174 high approach"):quit(1);return
 if not await jump_fence(scene,174):quit(1);return
 if not await walk(scene,route.yellow.points,"earned gold altar"):quit(1);return
 var charger=scene.get_node("Act2Chargers");scene.camera.look_at(charger.globes["L10:yellow"].global_position,Vector3.UP)
 if not check(charger.interact("L10:yellow","insert",id).ok,"Kit original43 gold charge"):quit(1);return
 var path:="res://tmp/l10_emperor_gold_occupied_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"gold occupied save/reload")
 scene.camera.look_at(charger.globes["L10:yellow"].global_position,Vector3.UP)
 if not check(charger.interact("L10:yellow","retrieve").ok,"Kit retrieves gold43"):quit(1);return
 if not await walk(scene,route.yellow_return.points,"return east entrance network"):quit(1);return
 if not await walk(scene,blue.exit_stairs.points,"original entrance stairs"):quit(1);return
 path="res://tmp/l10_emperor_three_globes_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual three globes aboveground save/reload")
 for item in [id+":charged:yellow","act2:L10_DC:item8:charged:white","act2:L10_DC:item9:charged:blue","act2:L9_DR:item55","act2:L10_DC:priest_ankh"]:check(item in scene.carried_collected,"reserved earned item "+item)
 check(scene.progression.seeds_applied.is_empty(),"no arrival seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned Emperor entry -> original breach -> original empty43 -> both high-side fences -> Kit gold -> physical surface return")
 quit(0 if failures==0 else 1)
