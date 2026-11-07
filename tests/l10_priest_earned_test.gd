extends "res://tests/l10_barrel_earned_test.gd"
const Priest=preload("res://scripts/lol2/l10_priest.gd")
func input_save()->String:return "res://tmp/l10_blue_return_earned_save.json"
func door_points(route: Dictionary)->Array:return route.door.points
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
 if not check(scene.apply_save(input.state).is_empty(),"actual blue return input"):quit(1);return
 prepare(scene)
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_priest_walk.json"))
 if not await walk(scene,door_points(route),"blue priest tomb154"):quit(1);return
 var tomb=scene.get_node("L10Tombs");scene.camera.look_at(tomb.aims["154"],Vector3.UP)
 var before: Array=scene.carried_collected.duplicate()
 check(not tomb.offer("154","act2:L10_DC:item8:charged:white").ok and before==scene.carried_collected,"wrong white refused without loss")
 check(scene._quicksave_unrecorded("res://tmp/l10_priest_door_earned_save.json").is_empty(),"actual priest door approach save")
 var offer: Dictionary=tomb.offer("154","act2:L10_DC:item45:charged:blue")
 if not check(offer.ok,"Kit consumes earned blue45 at priest154/155"):quit(1);return
 if not await walk(scene,route.priest.points,"original priest158"):quit(1);return
 var priest=scene.get_node("L10Priest");scene.camera.look_at(priest.AIM,Vector3.UP)
 var history: Dictionary=scene.quest_state.act2_items.duplicate(true)
 # Capacity-refusal vector uses the actual earned IDs; never changes the live inventory or save.
 var full: Dictionary=Priest.grant(priest.state(),scene.carried_collected,history,scene.carried_collected.size())
 check(not full.ok and history==scene.quest_state.act2_items,"full inventory transaction refuses without mutation")
 if not check(priest.speak().ok,"actual priest/bracers interaction gives original urn identity"):quit(1);return
 before=scene.carried_collected.duplicate()
 check(not priest.speak().ok and before==scene.carried_collected,"duplicate urn grant refused without loss")
 check(Priest.BRACERS in scene.carried_collected,"showing bracers does not consume them")
 var path:="res://tmp/l10_priest_urn_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"actual priest urn save/reload")
 check(priest.state().urn_given and Priest.URN in scene.carried_collected,"urn/history persist")
 check("act2:L10_DC:item9:charged:blue" in scene.carried_collected and "act2:L10_DC:item8:charged:white" in scene.carried_collected,"second blue and white retained")
 check(not priest.speak().ok,"load cannot repeat gift")
 check(scene.progression.seeds_applied.is_empty(),"no arrival seeds")
 scene.queue_free();await process_frame
 if failures==0:print("PASS earned two-blue return -> Kit blue154 -> actual priest158 with earned bracers -> source def78 urn once -> full/duplicate refusal -> actual save/reload")
 quit(0 if failures==0 else 1)
