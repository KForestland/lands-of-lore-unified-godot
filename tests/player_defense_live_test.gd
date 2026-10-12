extends "res://tests/player_magic_handoff_test.gd"
const Defense=preload("res://scripts/lol2/player_defense.gd")
func run() -> void:
	var path:="user://tests/player_defense.json"
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle);current_scene=jungle
	await process_frame
	jungle.set_physics_process(false);jungle.item_effects.set_process(false)
	# Supplied ownership fixture; original shop producer has independent earned proof.
	jungle.carried_collected=[Defense.BRACERS,"museum:item11:Fine_Longsword"]
	jungle.equipped_item="museum:item11:Fine_Longsword"
	if not check(jungle.open_inventory(),"Bracers inventory unavailable"): return
	var index:=0
	for i in jungle.inventory.item_list.item_count:
		if jungle.inventory.item_list.get_item_metadata(i)==Defense.BRACERS: index=i
	jungle.inventory.select_item(index)
	if not check(not jungle.inventory.equip_button.disabled,"Bracers equip disabled"): return
	jungle.inventory.equip_button.pressed.emit()
	if not check(Defense.scalar(jungle)==5 and jungle.equipped_item=="museum:item11:Fine_Longsword","Offhand lost weapon or defense"): return
	jungle.inventory.equip_button.pressed.emit()
	if not check(Defense.scalar(jungle)==0,"Unequip retained defense"): return
	jungle.inventory.equip_button.pressed.emit()
	jungle.inventory.close()
	await process_frame;await process_frame
	jungle.player_form=1
	if not check(Defense.scalar(jungle)==0 and not jungle.item_effects.equip_offhand(""),"Transformed equipment policy failed"): return
	jungle.player_form=0
	if not check(Defense.scalar(jungle)==5,"Human return lost bracers"): return
	if not check(jungle.quicksave(path).is_empty(),"Bracers save failed"): return
	var saved: Dictionary=jungle.Save.read_save(path).state
	var bad:=saved.duplicate(true)
	bad.inventory.item_effects.offhand="fake"
	var before: Dictionary=jungle.inventory_state().duplicate(true)
	if not check(not jungle.apply_save(bad).is_empty() and jungle.inventory_state()==before,"Invalid offhand load mutated live state"): return
	jungle.item_effects.equip_offhand("")
	if not check(jungle.quickload(path).is_empty() and Defense.scalar(jungle)==5,"Offhand rollback failed"): return
	# Firestorm's original definition8 contributes defense5 from the weapon slot.
	jungle.carried_collected.append("jungle:weapon_shop:Firestorm")
	jungle.equipped_item="jungle:weapon_shop:Firestorm"
	if not check(Defense.scalar(jungle)==10,"Firestorm and bracers defense did not combine"):return
	if not check(jungle.quicksave(path).is_empty(),"Firestorm defense save failed"):return
	jungle.equipped_item="museum:item11:Fine_Longsword"
	if not check(jungle.quickload(path).is_empty() and Defense.scalar(jungle)==10,"Firestorm defense restore failed"):return
	jungle.player_form=2
	if not check(Defense.scalar(jungle)==0,"Cursed form retained Firestorm defense"):return
	jungle.player_form=0
	jungle.carried_collected.erase("jungle:weapon_shop:Firestorm")
	if not check(Defense.scalar(jungle)==5,"Unowned Firestorm contributed defense"):return
	jungle.equipped_item="museum:item11:Fine_Longsword"
	var transfer: Dictionary=jungle.area_handoff()
	await finish(jungle)
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive);current_scene=hive
	await process_frame
	hive.set_physics_process(false);hive.item_effects.set_process(false)
	if not check(hive.apply_area_handoff(transfer).is_empty() and Defense.scalar(hive)==5,"Jungle/Hive offhand lost"): return
	if not check(hive.quicksave(path).is_empty(),"Hive offhand save failed"): return
	hive.item_effects.equip_offhand("")
	if not check(hive.quickload(path).is_empty() and Defense.scalar(hive)==5,"Hive offhand rollback failed"): return
	var live=hive.executioner_live
	live.set_physics_process(false)
	hive.get_node("Nest").chasm_handoff();hive.get_node("Nest").set_physics_process(false)
	var guards=hive.get_node("Warriors")
	guards.set_process(false)
	hive.player.position=live.SPAWN+Vector3(0,32,50)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for i in range(3): await physics_frame
	live.present()
	if not check(live.active() and live.in_reach(),"Incoming hit fixture not admitted"): return
	guards.health=30
	live.state.mode="attack";live.state.elapsed=0.0;live.state.hit_sent=false
	live.advance(0.6)
	if not check(guards.health==25,"Equipped live hit did not reduce6 to5"): return
	hive.item_effects.equip_offhand("")
	guards.health=30
	live.state.mode="attack";live.state.elapsed=0.0;live.state.hit_sent=false
	live.advance(0.6)
	if not check(guards.health==24,"Unequipped live hit changed baseline"): return
	hive.item_effects.equip_offhand(Defense.BRACERS)
	hive.starting_magic.set_process(false)
	hive.starting_magic.select_spell("heal")
	var mana_before: int=hive.starting_magic.magic_state().player.mana
	if not check(hive.starting_magic.cast() and hive.starting_magic.magic_state().player.mana==mana_before-2,"Bracers changed Healing cost"): return
	hive.starting_magic.magic_state().cooldown=0.0
	hive.starting_magic.select_spell("spark")
	hive.camera.rotation.x=-1.4
	mana_before=hive.starting_magic.magic_state().player.mana
	if not check(hive.starting_magic.cast() and hive.starting_magic.magic_state().player.mana==mana_before-1,"Bracers changed Spark cost"): return
	var onward: Dictionary=hive.area_handoff()
	await finish(hive)
	var darker=load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	root.add_child(darker);current_scene=darker
	await process_frame
	darker.set_physics_process(false);darker.item_effects.set_process(false)
	if not check(darker.apply_area_handoff(onward).is_empty() and Defense.scalar(darker)==5,"Darker handoff lost bracers"): return
	if not check(darker.quicksave(path).is_empty(),"Darker bracers save failed"): return
	await finish(darker)
	DirAccess.remove_absolute(path)
	print("PASS offhand UI/weapon/form/atomicity; live hits6->5; Spark/Healing unchanged; Jungle/Hive/darker save transport")
	quit()
