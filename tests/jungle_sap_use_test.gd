extends "res://tests/jungle_aloe_use_test.gd"
## Local pickup approaches, real inventory UI and saved consumption; not an earned route.
func use_sap(host, id: String) -> bool:
	if not check(host.open_inventory(), "Sap inventory did not open"): return false
	await process_frame
	var index := -1
	for i in host.inventory.item_list.item_count:
		if str(host.inventory.item_list.get_item_metadata(i)) == id: index = i
	if not check(index >= 0, "Sap absent from inventory"): return false
	host.inventory.select_item(index)
	if not check(host.inventory.use_button.visible and host.inventory.use_button.text == "Use sap", "Wrong sap action"): return false
	host.inventory.use_button.pressed.emit()
	await process_frame
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return check(id in host.item_effects.state().spent and id not in ids_of(host), "Sap was not consumed")

func run() -> void:
	var path := "user://tests/jungle_sap_use.json"
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/jungle_world_items/items.json"))
	for row in source.items:
		if int(row.row) in [52,53]:
			if not check(int(row.identity) == 1690340112 and int(row.definition) == 111 and int(row.handler) == 98, "Sap identity differs"): return
	set_meta("lol2_jungle_handoff", {"collected":[], "equipped_item":"", "equipped_armor":""})
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	for i in range(5): await process_frame
	freeze(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	items = scene.world_items
	for row in [52,53]:
		if not check(await face(row), "Cannot aim at sap %d" % row): return
		var key := InputEventKey.new(); key.keycode = KEY_E; key.pressed = true
		items._unhandled_input(key)
		if not check(World.id_of(row) in scene.carried_collected, "Sap pickup failed"): return
	var first := World.id_of(52)
	scene.starting_magic.set_health(17)
	var before: Dictionary = scene.item_effects.state().duplicate(true)
	scene.player_form = 1
	if not check(not scene.item_effects.use(first), "Transformed player consumed sap"): return
	scene.player_form = 0
	if not await use_sap(scene, first): return
	var expected: Dictionary = before.duplicate(true); expected.spent.append(first)
	if not check(scene.item_effects.state() == expected and scene.starting_magic.health() == 17, "Sap added an unsupported effect"): return
	if not check(not scene.item_effects.use(first), "Repeated sap use succeeded"): return
	if not check(scene.quicksave(path).is_empty(), "Sap save rejected"): return
	if not await use_sap(scene, World.id_of(53)): return
	if not check(scene.quickload(path).is_empty() and World.id_of(53) in scene.carried_collected and scene.item_effects.state() == expected, "Sap rollback failed"): return
	items.restore()
	if not check(not items.sprites[52].visible and not items.sprites[53].visible, "Picked sap respawned"): return
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var bad: Dictionary = saved.duplicate(true)
	bad.quests.jungle_world_items.collected.erase(52.0); bad.quests.jungle_world_items.collected.erase(52)
	if not check(not Save.validate(bad).is_empty(), "Consumed sap without pickup history accepted"): return
	bad = saved.duplicate(true); bad.inventory.item_effects.spent.append(first)
	if not check(not Save.validate(bad).is_empty(), "Duplicate sap consumption accepted"): return
	var handoff: Dictionary = scene.area_handoff()
	await finish(scene)
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	await process_frame
	hive.item_effects.set_process(false); hive.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not check(hive.apply_area_handoff(JSON.parse_string(JSON.stringify(handoff))).is_empty(), "Hive rejected sap state"): return
	if not await use_sap(hive, World.id_of(53)): return
	if not check(hive.quicksave(path).is_empty() and hive.quickload(path).is_empty(), "Hive sap save/load failed"): return
	var back: Dictionary = hive.area_handoff()
	await finish(hive)
	var darker = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	root.add_child(darker); current_scene = darker
	for i in range(5): await process_frame
	freeze(darker)
	if not check(darker.apply_area_handoff(JSON.parse_string(JSON.stringify(back))).is_empty(), "Darker jungle rejected sap state"): return
	if not check(first in darker.item_effects.state().spent and World.id_of(53) in darker.item_effects.state().spent, "Sap history lost on travel"): return
	await finish(darker)
	DirAccess.remove_absolute(path)
	print("PASS sap source identity, E pickups, UI use, form gate, no stat effect, no repeated use, disk rollback, no respawn, invalid history rejection and Jungle/Hive/darker transport; supplied approaches.")
	quit()
