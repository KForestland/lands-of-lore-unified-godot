extends "res://tests/l10_tomb_earned_test.gd"
func run():
 var input:=Save.read_save("res://tmp/l10_catacomb_earned_save.json","lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"earned catacomb load"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_tomb_walk.json"))
 if not await walk(scene,route.charger,"charger"):quit(1);return
 var charger=scene.get_node("Act2Chargers")
 var id:="act2:L10_DC:item44"
 scene.camera.look_at(charger.globes["L10:yellow"].global_position,Vector3.UP)
 var before: Array=scene.carried_collected.duplicate()
 check(not charger.interact("L10:yellow","insert","l8:shaman:Dracoid_sigil").ok and before==scene.carried_collected,"wrong carried sigil refused without loss")
 if not check(charger.interact("L10:yellow","insert",id).ok,"insert earned empty globe"):quit(1);return
 var occupied:="res://tmp/l10_gold_occupied_save.json"
 check(scene._quicksave_unrecorded(occupied).is_empty(),"occupied charger save")
 check(scene._quickload_unrecorded(occupied).is_empty(),"occupied charger reload")
 charger.restore();scene.camera.look_at(charger.globes["L10:yellow"].global_position,Vector3.UP)
 check(charger.globes["L10:yellow"].visible and id not in scene.carried_collected,"occupied globe restored without duplicate inventory")
 check(charger.interact("L10:yellow","retrieve").ok,"retrieve earned gold globe")
 check(not charger.interact("L10:yellow","retrieve").ok,"duplicate retrieval refused")
 var path:="res://tmp/l10_gold_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"retrieved actual save/reload")
 check(scene.carried_collected.count(id+":charged:yellow")==1,"one earned charged instance")
 scene.queue_free();await process_frame
 if failures==0:print("PASS STORY-009 charging leg from earned008 save; original altar and occupied/retrieved saves. Book low-fence placement/direction remains unqualified.")
 quit(0 if failures==0 else 1)
