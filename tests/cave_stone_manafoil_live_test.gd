extends "res://tests/player_magic_handoff_test.gd"
## Actual Cave host: prop1050 Ancient Stone and control75 Mana foil taken through the real E path (host input ->
## _update_interaction), each once; the stone leaves the world, the foil marker hides; capacity refusal; save/load;
## save validation (bad ids, consumed stone requires pickup); Ancient Stone use (shared handler6 counter) through the
## inventory; Cave -> Museum transfer keeps both items and the consumed history. Supplied vantage.
const Owner = preload("res://scripts/lol2/cave_stone_manafoil.gd")
func press_e(cave) -> void:
	var event := InputEventKey.new(); event.keycode = KEY_E; event.pressed = true
	cave._unhandled_input(event)
	cave._update_interaction()
	await process_frame
func view(cave, id: String) -> bool:
	var o = cave.stone_manafoil
	var target: Vector3 = o.aim_point(id)
	for distance in [45.0, 30.0, 65.0]:
		for step in 12:
			var d := Vector3(cos(step * TAU / 12.0), 0, sin(step * TAU / 12.0))
			cave.player.global_position = target + d * distance + Vector3(0, 20, 0)
			cave.player.rotation = Vector3.ZERO; cave.camera.rotation = Vector3.ZERO
			await physics_frame
			cave.camera.look_at(target); await physics_frame
			if o.target() == id: return true
	return false
func run() -> void:
	var path := "user://tests/cave_stone_manafoil.json"
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	current_scene = cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready and cave.item_effects != null: break
	assert(cave.walkthrough_ready and cave.item_effects != null and cave.stone_manafoil != null)
	cave.set_physics_process(false)
	cave.item_effects.set_process(false)
	cave.starting_magic.set_process(false)
	cave.flying = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var o = cave.stone_manafoil
	assert(o.stone.visible and o.foil_marker.visible and o.collected.is_empty())
	# Ancient Stone.
	assert(await view(cave, Owner.STONE))
	cave._process(0.0)
	assert(cave.interaction_prompt.text == "E · Take Ancients' Stone")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/cave_stone_view.png")
	await press_e(cave)
	assert(Owner.STONE in cave.carried_items() and not o.stone.visible and o.target() != Owner.STONE)
	await press_e(cave)
	assert(cave.carried_items().count(Owner.STONE) == 1)
	# Mana foil: capacity refusal first (atomic), then the take.
	assert(await view(cave, Owner.FOIL))
	cave._process(0.0)
	assert(cave.interaction_prompt.text == "E · Take Mana Foil")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/cave_foil_view.png")
	var Catalog = preload("res://scripts/lol2/item_catalog.gd")
	# Capacity: pad the real host's carried list (via its Aloe list) to MAX_CARRIED; the take must change nothing.
	var saved_aloe: Array = cave.aloe.collected.duplicate()
	while cave.carried_items().size() < Catalog.MAX_CARRIED: cave.aloe.collected.append("pad%d" % cave.aloe.collected.size())
	await press_e(cave)
	assert(not Owner.FOIL in cave.carried_items() and o.collected.size() == 1 and o.foil_marker.visible)
	cave.aloe.collected = saved_aloe
	await press_e(cave)
	assert(Owner.FOIL in cave.carried_items() and not o.foil_marker.visible)
	await press_e(cave)
	assert(cave.carried_items().count(Owner.FOIL) == 1)
	# Save / load.
	assert(cave._quicksave(path).is_empty())
	o.restore([])
	assert(cave._quickload(path).is_empty())
	assert(o.collected == [Owner.STONE, Owner.FOIL] and not o.stone.visible and not o.foil_marker.visible)
	var bad: Dictionary = cave._save_state(); bad.stone_manafoil = [Owner.STONE, Owner.STONE]
	assert(not cave.WalkthroughSave.validate(bad, cave._checkpoint_count()).is_empty())
	bad = cave._save_state(); bad.stone_manafoil = ["cave:prop1050:Wrong"]
	assert(not cave.WalkthroughSave.validate(bad, cave._checkpoint_count()).is_empty())
	# Ancient Stone use through the inventory (shared handler6 counter); the consumed stone needs its pickup.
	var event := InputEventKey.new(); event.keycode = KEY_I; event.pressed = true
	cave._unhandled_input(event)
	await process_frame
	var ids: Array = cave.carried_items()
	cave.inventory.select_item(ids.find(Owner.STONE))
	assert(cave.inventory.use_button.visible)
	var charges: int = int(cave.item_effects.state().get("ancient_charges", 0))
	cave.inventory.use_button.pressed.emit()
	await process_frame
	await process_frame
	assert(Owner.STONE in cave.item_effects.state().spent and Owner.STONE not in cave.carried_items() and int(cave.item_effects.state().ancient_charges) == charges + 1)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	assert(cave.WalkthroughSave.validate(cave._save_state(), cave._checkpoint_count()).is_empty())
	bad = cave._save_state(); bad.stone_manafoil = [Owner.FOIL]
	assert(not cave.WalkthroughSave.validate(bad, cave._checkpoint_count()).is_empty())
	assert(preload("res://scripts/lol2/player_item_state.gd").validate(cave.item_effects.state(), cave.carried_items()).is_empty())
	# Identities.
	var Names = preload("res://scripts/lol2/act_one_item_names.gd")
	assert(Names.source_name(Owner.STONE) == "66-Ancients stn" and Names.source_name(Owner.FOIL) == "131-Mana foil")
	assert(Catalog.use_kind(Owner.STONE) == "ancient" and Catalog.use_kind(Owner.FOIL) == "" and Catalog.admitted(Owner.STONE, "cave") and Catalog.admitted(Owner.FOIL, "cave"))
	# Cave -> Museum.
	set_meta("lol2_cave_completion", cave._completion_state())
	await finish(cave)
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum)
	current_scene = museum
	await process_frame
	museum.item_effects.set_process(false)
	museum.set_physics_process(false)
	assert(Owner.FOIL in museum.carried_inventory.collected if museum.get("carried_inventory") != null else Owner.FOIL in museum.carried_collected)
	assert(Owner.STONE in museum.item_effects.state().spent and int(museum.item_effects.state().ancient_charges) == charges + 1)
	assert(museum.quicksave(path).is_empty() and museum.quickload(path).is_empty())
	# Supplied lit-room reward fixture checks the second origin against the earned cave consumption above.
	var carried: Dictionary = museum.inventory_state()
	await finish(museum)
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	for i in 3: await process_frame
	hive.set_physics_process(false)
	var transfer: Dictionary = hive.area_handoff()
	transfer.inventory = carried
	transfer.inventory.collected.append(preload("res://scripts/lol2/hive_ancient_stone.gd").ITEM)
	transfer.quests.hive_rune_entry.flag7 = true
	assert(hive.apply_area_handoff(transfer).is_empty())
	var second: String = preload("res://scripts/lol2/hive_ancient_stone.gd").ITEM
	assert(hive.open_inventory())
	hive.inventory.select_item(hive.carried_inventory.collected.find(second))
	hive.inventory.use_button.pressed.emit()
	await process_frame
	assert(int(hive.item_effects.state().ancient_charges) == charges + 2)
	assert(Owner.STONE in hive.item_effects.state().spent and second in hive.item_effects.state().spent)
	assert(not hive.item_effects.use(second))
	if is_instance_valid(hive.inventory): hive.inventory.close()	# Use may already close the panel.
	await process_frame
	assert(hive.quicksave(path).is_empty() and hive.quickload(path).is_empty())
	assert(int(hive.item_effects.state().ancient_charges) == charges + 2)
	var onward: Dictionary = hive.area_handoff()
	await finish(hive)
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in 3: await process_frame
	assert(jungle.apply_area_handoff(onward).is_empty())
	assert(int(jungle.item_effects.state().ancient_charges) == charges + 2)
	assert(jungle.quicksave(path).is_empty() and jungle.quickload(path).is_empty())
	print("PASS dual-origin Ancient Stones: cave inventory use + supplied Hive reward, two charges, no repeated consumption, Hive/Jungle disk saves.")
	print("PASS cave_stone_manafoil_live: prop1050 stone and control75 foil via host E (once each, stone hidden, marker hidden), capacity guard, save/load and validation, Ancient Stone inventory use (shared counter, pickup history), Cave->Museum transfer.")
	quit()
