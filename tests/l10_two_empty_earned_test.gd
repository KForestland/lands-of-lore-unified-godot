extends "res://tests/l9_opening_earned_test.gd"
func run():
 Engine.time_scale=4;Engine.physics_ticks_per_second=240
 var input:=Save.read_save("res://tmp/l10_bracers_return_earned_save.json","lol2-restoration-map-L10_DC")
 if not check(input.error.is_empty(),input.error):quit(1);return
 set_meta("lol2_map_start_selector",2)
 var scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
 scene.adapter_exit_seeds=false;root.add_child(scene);current_scene=scene
 for i in 1500:
  await process_frame
  if scene.ready_for_review:break
 if not check(scene.apply_save(input.state).is_empty(),"actual bracers+gold Cemetery return"):quit(1);return
 scene.player.set_physics_process(false);scene.set_physics_process(false)
 scene.starting_magic.interface_request=true;scene.progression.change_scene_enabled=false
 var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l10_two_empty_walk.json"))
 if not await walk(scene,route.door.points,"gold tomb91"):quit(1);return
 var tomb=scene.get_node("L10Tombs")
 scene.camera.look_at(tomb.aims["91"],Vector3.UP)
 var before: Array=scene.carried_collected.duplicate()
 check(not tomb.offer("91","l8:shaman:Dracoid_sigil").ok and before==scene.carried_collected,"wrong carried sigil refused without loss")
 if not check(tomb.offer("91","act2:L10_DC:item44:charged:yellow").ok,"spend earned gold44 at source91 through Kit"):quit(1);return
 check(scene._quicksave_unrecorded("res://tmp/l10_gold91_earned_save.json").is_empty(),"actual opened tomb91 save")
 if not await walk(scene,route.lid.points,"Crypt Top67"):quit(1);return
 var item:="act2:L10_DC:item56"
 scene.camera.look_at(scene.act2_items.aim_point(item),Vector3.UP)
 print("ORIGINAL LID SIDE PICKUP player",scene.player.position," aim",scene.act2_items.aim_point(item))
 if not check(scene.act2_items.take(item),"original empty56 pickup beside unchanged lid"):quit(1);return
 if not await walk(scene,route.free.points,"free globe8"):quit(1);return
 scene.camera.look_at(scene.act2_items.aim_point("act2:L10_DC:item8"),Vector3.UP)
 if not check(scene.act2_items.take("act2:L10_DC:item8"),"original loose empty8 pickup"):quit(1);return
 var path:="res://tmp/l10_two_empty_earned_save.json"
 check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(),"two original empties actual save/reload")
 for id in ["act2:L10_DC:item56","act2:L10_DC:item8","act2:L9_DR:item55"]:check(id in scene.carried_collected,"earned item persists "+id)
 check("act2:L10_DC:item44:charged:yellow" not in scene.carried_collected and tomb.opened("91"),"gold spent once; door persists")
 scene.queue_free();await process_frame
 if failures==0:print("PASS actual bracers+gold return -> Kit gold91 -> natural side pickup beside original Crypt Top67 -> original56 and8 -> real save/reload; no invented Tower reward, no merged inventories")
 quit(0 if failures==0 else 1)
