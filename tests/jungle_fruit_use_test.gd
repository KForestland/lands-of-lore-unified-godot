extends "res://tests/jungle_aloe_use_test.gd"
## Vels fruit rows54-57 (definition84/handler20): local pickup approaches, real E pickups, real inventory UI and saved
## consumption; not an earned route.
## - Source identity 102901910/definition84/handler20 for all four rows; catalog use "vels_fruit"; button "Eat fruit".
## - Transformed or dead Luther cannot eat (the existing item owners' living-human admission).
## - Eating removes exactly that fruit into spent history and changes nothing else (no heal, mana or effect state);
##   the native status cure has no port status to clear.
## - Repeat use refused; disk rollback; picked fruit never respawns; invalid/duplicate history rejected.
## - Jungle→Hive (eat there)→darker-jungle transport keeps the history. Sap/Aloe are covered by their own tests.
const FRUIT:=[54,55,56,57]
func eat(host, id: String) -> bool:
	if not check(host.open_inventory(), "Fruit inventory did not open"): return false
	await process_frame
	var index := -1
	for i in host.inventory.item_list.item_count:
		if str(host.inventory.item_list.get_item_metadata(i)) == id: index = i
	if not check(index >= 0, "Fruit absent from inventory"): return false
	host.inventory.select_item(index)
	if not check(host.inventory.use_button.visible and host.inventory.use_button.text == "Eat fruit", "Wrong fruit action: %s"%host.inventory.use_button.text): return false
	host.inventory.use_button.pressed.emit()
	await process_frame
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return check(id in host.item_effects.state().spent and id not in ids_of(host), "Fruit was not consumed")

func run() -> void:
	var path := "user://tests/opus_fruit_use.json"
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/jungle_world_items/items.json"))
	var seen := 0
	for row in source.items:
		if int(row.row) in FRUIT:
			seen += 1
			if not check(int(row.identity) == 102901910 and int(row.definition) == 84 and int(row.handler) == 20 and Catalog.use_kind(World.id_of(int(row.row))) == "vels_fruit", "Fruit row %d identity/use differs" % int(row.row)): return
	if not check(seen == 4, "Expected four fruit rows"): return
	set_meta("lol2_jungle_handoff", {"collected":[], "equipped_item":"", "equipped_armor":""})
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	for i in range(5): await process_frame
	freeze(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	items = scene.world_items
	for row in FRUIT:
		if not check(await face(row), "Cannot aim at fruit %d" % row): return
		var key := InputEventKey.new(); key.keycode = KEY_E; key.pressed = true
		items._unhandled_input(key)
		if not check(World.id_of(row) in scene.carried_collected, "Fruit %d pickup failed" % row): return
	var first := World.id_of(54)
	scene.starting_magic.set_health(17)
	var before: Dictionary = scene.item_effects.state().duplicate(true)
	var magic_before: Dictionary = scene.starting_magic.magic_state().duplicate(true)
	scene.player_form = 1
	if not check(not scene.item_effects.use(first) and first in scene.carried_collected, "Transformed player ate fruit"): return
	scene.player_form = 0
	scene.starting_magic.set_health(0)
	if not check(not scene.item_effects.use(first) and first in scene.carried_collected, "Dead player ate fruit"): return
	scene.starting_magic.set_health(17)
	if not await eat(scene, first): return
	var expected: Dictionary = before.duplicate(true); expected.spent.append(first)
	if not check(scene.item_effects.state() == expected and scene.starting_magic.health() == 17 and scene.starting_magic.magic_state() == magic_before, "Fruit added an unsupported effect"): return
	if not check(not scene.item_effects.use(first), "Repeated fruit use succeeded"): return
	if not check(scene.quicksave(path).is_empty(), "Fruit save rejected"): return
	if not await eat(scene, World.id_of(55)): return
	if not check(scene.quickload(path).is_empty() and World.id_of(55) in scene.carried_collected and scene.item_effects.state() == expected, "Fruit rollback failed"): return
	items.restore()
	for row in FRUIT:
		if not check(not items.sprites[row].visible, "Picked fruit %d respawned" % row): return
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var bad: Dictionary = saved.duplicate(true)
	bad.quests.jungle_world_items.collected.erase(54.0); bad.quests.jungle_world_items.collected.erase(54)
	if not check(not Save.validate(bad).is_empty(), "Eaten fruit without pickup history accepted"): return
	bad = saved.duplicate(true); bad.inventory.item_effects.spent.append(first)
	if not check(not Save.validate(bad).is_empty(), "Duplicate fruit consumption accepted"): return
	bad = saved.duplicate(true); bad.inventory.item_effects.spent.append(World.id_of(56))
	if not check(not Save.validate(bad).is_empty(), "Fruit both carried and eaten accepted"): return
	var handoff: Dictionary = scene.area_handoff()
	await finish(scene)
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	await process_frame
	hive.item_effects.set_process(false); hive.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not check(hive.apply_area_handoff(JSON.parse_string(JSON.stringify(handoff))).is_empty(), "Hive rejected fruit state"): return
	if not await eat(hive, World.id_of(55)): return
	if not check(hive.quicksave(path).is_empty() and hive.quickload(path).is_empty() and World.id_of(55) in hive.item_effects.state().spent, "Hive fruit save/load failed"): return
	var back: Dictionary = hive.area_handoff()
	await finish(hive)
	var darker = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	root.add_child(darker); current_scene = darker
	for i in range(5): await process_frame
	freeze(darker)
	if not check(darker.apply_area_handoff(JSON.parse_string(JSON.stringify(back))).is_empty(), "Darker jungle rejected fruit state"): return
	var spent: Array = darker.item_effects.state().spent
	if not check(first in spent and World.id_of(55) in spent and World.id_of(56) not in spent and World.id_of(56) in darker.carried_collected, "Fruit history lost on travel"): return
	await finish(darker)
	DirAccess.remove_absolute(path)
	print("PASS fruit source identity (4 rows), E pickups, Eat fruit UI, form/dead gates, consumption without stat effect, no repeated use, disk rollback, no respawn, invalid history rejection and Jungle/Hive(eat)/darker transport; supplied approaches.")
	quit()
