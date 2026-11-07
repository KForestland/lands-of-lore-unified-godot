extends SceneTree
## Dark Halls item-giving controls (prepare_dark_halls_loot.py): every grant of the 8 controls is taken with the
## production E handler while facing the control; ids match dark_halls_items.gd and are admitted carried items;
## a third press on a two-use control gives nothing; uses and items survive quicksave/quickload.
const Items = preload("res://scripts/lol2/dark_halls_items.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL dark_halls_loot: ", message); quit(1); return false
func press_e(scene: Node) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = KEY_E; e.physical_keycode = KEY_E; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
		await process_frame
func run() -> void:
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for i in range(1500):
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	var scene = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("Dark Halls not ready")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if scene.creatures != null: scene.creatures.set_physics_process(false); scene.creatures.set_process(false)
	var loot = scene.get("loot")
	if loot == null: return fail("Loot host missing")
	var source_ids: Array = []
	for c in loot.source.controls:
		for g in c.grants: source_ids.append(g.id)
	source_ids.append(loot.source.rix.corpse.id)
	source_ids.sort()
	var item_ids: Array = Items.ITEMS.keys(); item_ids.sort()
	if source_ids != item_ids: return fail("dark_halls_items.gd differs from the loot source")
	for id in source_ids:
		if not Catalog.admitted(id, "jungle"): return fail("Catalog does not admit " + id)
	scene.set_physics_process(false)
	for c in loot.source.controls:
		var point := Vector3(c.position[0], c.position[1], c.position[2])
		scene.player.global_position = point + Vector3(60, 34, 0); scene.player.velocity = Vector3.ZERO
		scene.camera.look_at(point + Vector3(0, 24, 0))
		await physics_frame
		for g in c.grants:
			await press_e(scene)
			if not g.id in scene.carried_collected: return fail("E did not take %s from control %d" % [g.id, int(c.control)])
		var before: int = scene.carried_collected.size()
		await press_e(scene)
		if scene.carried_collected.size() != before: return fail("Exhausted control %d gave more" % int(c.control))
	if Catalog.validate_carried(scene.carried_collected, "jungle") != "": return fail("Carried list rejected: " + Catalog.validate_carried(scene.carried_collected, "jungle"))
	var path := "user://tests/dark_halls_loot.json"
	if not scene.quicksave(path).is_empty(): return fail("Quicksave failed")
	var carried: Array = scene.carried_collected.duplicate()
	var uses: Dictionary = scene.quest_state.dark_halls_loot.duplicate()
	scene.carried_collected.clear(); scene.quest_state.erase("dark_halls_loot")
	var saved := preload("res://scripts/lol2/jungle_save.gd").read_save(path, preload("res://scripts/lol2/dark_halls.gd").FORMAT)
	if not str(saved.error).is_empty(): return fail("Read save: " + str(saved.error))
	var error: String = scene.apply_save(saved.state)
	if not error.is_empty(): return fail("Apply save: " + error)
	for id in source_ids:
		if id != loot.source.rix.corpse.id and not id in scene.carried_collected: return fail("Reload lost " + id)
	var reloaded: Dictionary = scene.quest_state.get("dark_halls_loot", {})
	if reloaded.size() != uses.size(): return fail("Reload lost the control uses")
	for key in uses:
		if int(reloaded.get(key, -1)) != int(uses[key]): return fail("Reload changed the uses of control " + str(key))
	print("PASS dark_halls_loot: %d grants from %d controls taken with E, catalog-admitted, exhausted controls inert, kept across quicksave/quickload" % [source_ids.size() - 1, loot.source.controls.size()])
	quit(0)
