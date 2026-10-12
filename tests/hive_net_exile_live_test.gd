extends SceneTree
## Actual Hive host: prop214 pile searched by E (one "26-Net of Exile", state1, pile stays), repeat refused, disk
## reload, transport validation (carried Net without pickup history rejected), capacity refusal, identities
## (source name, catalog weapon, defense row, equip), Hive -> Jungle handoff. Supplied vantage.
const Net = preload("res://scripts/lol2/hive_net_exile.gd")
var hive
var owner
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true; push_error(message); quit(1)
	return ok
func press_e() -> void:
	var event := InputEventKey.new(); event.keycode = KEY_E; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
	event = InputEventKey.new(); event.keycode = KEY_E; event.pressed = false
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func view() -> bool:
	var target: Vector3 = owner.aim_point()
	var floor_y: float = float(owner.source.position[1])
	for distance in [60.0, 45.0, 85.0]:
		for step in 16:
			var d := Vector3(cos(step * TAU / 16.0), 0, sin(step * TAU / 16.0))
			hive.player.global_position = Vector3(target.x, floor_y + 32.0, target.z) + d * distance
			hive.player.velocity = Vector3.ZERO; hive.player.rotation = Vector3.ZERO; hive.camera.rotation = Vector3.ZERO
			await physics_frame
			hive.camera.look_at(target); await physics_frame
			if owner.target(): return true
	return false
func cycle(tag: String) -> bool:
	var path := "user://tests/hive_net_exile_%s.json" % tag
	var error: String = hive.quicksave(path)
	if not check(error.is_empty(), "Save %s: %s" % [tag, error]): return false
	var before: Dictionary = owner.checkpoint(); var items: Array = hive.carried_inventory.collected.duplicate()
	error = hive.quickload(path)
	hive.set_physics_process(false)
	return check(error.is_empty() and int(owner.checkpoint().state) == int(before.state) and hive.carried_inventory.collected == items, "Reload %s: %s" % [tag, error])
func run() -> void:
	hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	for i in 10: await process_frame
	hive.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	owner = hive.net_exile
	if not check(is_instance_valid(owner) and owner.checkpoint() == Net.initial() and owner.sprite.visible, "Net owner missing/not initial"): return
	if not check(await view(), "No vantage for prop214"): return
	if not check(owner.interaction_hint() == "E — Search the pile", "Hint: " + owner.interaction_hint()): return
	await process_frame
	await process_frame  # the owner's prompt refresh runs after the HUD's in frame order
	if not check(hive.interface_hud.hint.text == "E — Search the pile", "HUD prompt: " + hive.interface_hud.hint.text): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/hive_net_pile.png")
	# Capacity refusal is atomic.
	var Catalog = preload("res://scripts/lol2/item_catalog.gd")
	var start: Array = hive.carried_inventory.collected.duplicate()
	var filler: Array = Catalog.ids("jungle").filter(func(id): return not id in start and id != Net.ITEM)
	while hive.carried_inventory.collected.size() < Catalog.MAX_CARRIED: hive.carried_inventory.collected.append(filler.pop_back())
	var capped: Array = hive.carried_inventory.collected.duplicate()
	await press_e()
	if not check(hive.carried_inventory.collected == capped and int(owner.state.state) == 0, "Harvest beyond MAX_CARRIED"): return
	hive.carried_inventory.collected = start
	await press_e()
	if not check(hive.carried_inventory.collected.count(Net.ITEM) == 1 and int(owner.state.state) == 1 and owner.sprite.visible, "Search: %s" % [owner.state]): return
	await press_e()
	if not check(hive.carried_inventory.collected.count(Net.ITEM) == 1 and owner.interaction_hint() == "Nothing else in the pile.", "Second search"): return
	if not cycle("taken"): return
	if not await view(): return
	await press_e()
	if not check(hive.carried_inventory.collected.count(Net.ITEM) == 1, "Reload regranted"): return
	# Validation and transport.
	if not check(not Net.validate({"version":1,"state":2}).is_empty() and not Net.validate({"version":1}).is_empty(), "Invalid state accepted"): return
	if not check(not Net.transport_error({"collected":[Net.ITEM]}, {}).is_empty() and Net.transport_error({"collected":[Net.ITEM]}, {"hive_net_exile":{"version":1,"state":1}}).is_empty(), "Transport rule"): return
	var Names = preload("res://scripts/lol2/act_one_item_names.gd")
	var defense: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/act-one-item-defenses.json")).items
	if not check(Names.source_name(Net.ITEM) == "26-Net of Exile" and preload("res://scripts/lol2/player_equipment.gd").weapon(Net.ITEM) and Catalog.admitted(Net.ITEM, "jungle") and not Catalog.admitted(Net.ITEM, "museum") and defense.has(Net.ITEM) and int(defense[Net.ITEM].defense) == 0, "Net identity"): return
	if not check(hive.set_equipped_item(Net.ITEM) and hive.equipped_item == Net.ITEM, "Equip Net"): return
	# Hive -> Jungle handoff keeps the Net and its history; a forged handoff without the history is rejected.
	var handoff: Dictionary = hive.area_handoff()
	if not check(int(handoff.quests.hive_net_exile.state) == 1, "Handoff lacks Net history"): return
	var forged: Dictionary = handoff.duplicate(true); forged.quests.erase("hive_net_exile")
	if not check(not hive.apply_area_handoff(JSON.parse_string(JSON.stringify(forged, "", true, true))).is_empty(), "Forged Net handoff accepted"): return
	hive.queue_free(); await process_frame; await process_frame
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in 3: await process_frame
	var error: String = jungle.apply_area_handoff(JSON.parse_string(JSON.stringify(handoff, "", true, true)))
	if not check(error.is_empty() and Net.ITEM in jungle.carried_collected, "Jungle handoff: " + error): return
	print("PASS hive_net_exile_live: prop214 E search (one 26-Net of Exile, pile stays), repeat/reload refused, capacity atomic, transport history rule, identity/weapon/defense/equip, Hive->Jungle handoff.")
	quit()
