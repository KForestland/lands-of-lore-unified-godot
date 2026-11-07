extends "res://tests/l9_opening_earned_test.gd"
const Items=preload("res://scripts/lol2/act2_items_catalog.gd")
func run():
 var input:=Save.read_save("res://tmp/l9_white_altar_earned_save.json","lol2-restoration-dragon-preview")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",1)
 var scene=load("res://scenes/lol2/dragon_level.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual one-globe Tower save"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 var original:Array=scene.carried_collected.duplicate()
 check(original.filter(func(id):return Items.definition(id) in [98,99,100,101]).size()==1,"earned input carries exactly one globe")
 var world=scene.get_node("Act2WorldItems")
 scene.camera.look_at(world.aim_point(Items.TOWER_BLANK),Vector3.UP)
 if not check(world.take(Items.TOWER_BLANK),"actual aimed Tower blank pickup"):quit(1);return
 check(not world.take(Items.TOWER_BLANK),"duplicate pickup refused")
 var path:="res://tmp/l9_tower_blank_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"blank pickup save/reload")
 check(not world.sprites[Items.TOWER_BLANK].visible,"collected blank stays absent")
 var charger=scene.get_node("Act2Chargers")
 scene.camera.look_at(charger.globes["L9:white"].global_position,Vector3.UP)
 check(not charger.interact("L9:white","insert",original[0]).ok,"wrong item refused")
 if not check(charger.interact("L9:white","insert",Items.TOWER_BLANK).ok,"earned blank charged via Kit"):quit(1);return
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"occupied Kit save/reload")
 check(Items.TOWER_BLANK not in scene.carried_collected,"occupied blank not also carried")
 scene.camera.look_at(charger.globes["L9:white"].global_position,Vector3.UP)
 var retrieved:Dictionary=charger.interact("L9:white","retrieve")
 check(retrieved.ok,"retrieve white globe "+str(retrieved.get("reason","")))
 check(not charger.interact("L9:white","retrieve").ok,"duplicate retrieval refused")
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"white output save/reload")
 check(scene.carried_collected.count(Items.TOWER_BLANK+":charged:white")==1,"one charged output persists")
 for id in original:check(id in scene.carried_collected,"original inventory preserved "+id)
 check(scene.progression.seeds_applied.is_empty(),"no route seeding")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual one-globe Tower branch -> aimed blank pickup -> Kit white charge -> occupied/retrieved reload; no inventory merge")
 quit(0 if failures==0 else 1)
