extends SceneTree
## Dark Halls window puzzle (prepare_dark_halls_windows.py) with the earned R18 monastery quests (LOL2_EARNED_SAVES):
## exits shut at the start; six windows opened with the production E handler from the dome floor and one with the
## Spark ray; the counter reads n/7; the 7th runs the orb end once (soul +1, the 18 grid SHADEs gone, orb hidden,
## exits open); an 8th window stays shut; state survives quicksave/quickload; an invalid saved state is rejected.
const Save = preload("res://scripts/lol2/jungle_save.gd")
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL dark_halls_windows: ", message); quit(1); return false
func press_e() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = KEY_E; e.physical_keycode = KEY_E; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
		await process_frame
func face(scene, windows, w: Dictionary) -> void:
	var centre: Vector3 = windows._vec(w.center)
	var inward: Vector3 = windows._inward(w)
	scene.player.global_position = Vector3(centre.x, 760.0 + 32.0, centre.z) + inward * 70.0
	scene.player.velocity = Vector3.ZERO
	await physics_frame
	scene.camera.look_at(centre)
	await physics_frame
func run() -> void:
	var saves := OS.get_environment("LOL2_EARNED_SAVES")
	if saves.is_empty(): return fail("LOL2_EARNED_SAVES is required")
	var earned := Save.read_save(saves + "/act1_broken_repaired_monastery.json")
	if not str(earned.error).is_empty(): return fail("Earned save: " + str(earned.error))
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for i in range(1500):
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	var scene = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("Dark Halls not ready")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var error: String = scene.apply_area_handoff({"inventory": earned.state.inventory, "quests": earned.state.quests})
	if not error.is_empty(): return fail("Earned handoff: " + error)
	var pop = scene.creatures
	pop.set_physics_process(false); pop.set_process(false)
	var windows = scene.windows
	if windows == null: return fail("Window host missing")
	if windows.source.windows.size() != 15 or int(windows.source.target) != 7: return fail("Source is not 15 windows / 7")
	if scene.exits_open(): return fail("Exits open before the puzzle")
	if not scene.prop_nodes.has(int(windows.source.orb.prop)) or not scene.prop_nodes[int(windows.source.orb.prop)].visible: return fail("Orb not shown")
	var soul := int(scene.quest_state.monastery.globals.GV_LUTHERS_SOUL)
	scene.set_physics_process(false)
	var list: Array = windows.source.windows
	for k in 6:
		await face(scene, windows, list[k])
		if windows.aimed_window() != int(list[k].control): return fail("Window %d not aimed from the dome floor (aimed %d)" % [int(list[k].control), windows.aimed_window()])
		await press_e()
		if windows.opened().size() != k + 1: return fail("E did not open window %d" % int(list[k].control))
		if windows.counter.text != "Windows opened:\n%d/7" % (k + 1): return fail("Counter reads %s" % windows.counter.text)
		await press_e()
		if windows.opened().size() != k + 1: return fail("Second E on an open window counted again")
	if windows.done() or scene.exits_open(): return fail("Puzzle done after 6")
	# 7th by the production Spark ray (player_starting_magic.spark: the spark_receiver path).
	await face(scene, windows, list[6])
	scene.starting_magic.spark()
	if windows.opened().size() != 7 or not windows.done(): return fail("Spark did not open window %d" % int(list[6].control))
	var globals: Dictionary = scene.quest_state.monastery.globals
	if int(globals.GV_LUTHERS_SOUL) != soul + 1: return fail("Soul %d -> %d, expected +1" % [soul, int(globals.GV_LUTHERS_SOUL)])
	for id in windows.source.orb.shades:
		if int(pop.state.actors[id].health) != 0: return fail("Grid SHADE %s survived the orb end" % id)
	if int(pop.state.actors["24"].health) == 0: return fail("The lone SHADE 24 is not in the orb end group")
	if scene.prop_nodes[int(windows.source.orb.prop)].visible: return fail("Orb still shown")
	if not scene.exits_open(): return fail("Exits shut after the puzzle")
	await face(scene, windows, list[7])
	await press_e()
	if windows.opened().size() != 7 or int(globals.GV_LUTHERS_SOUL) != soul + 1: return fail("Puzzle continued after the end")
	var path := "user://tests/dark_halls_windows.json"
	if not scene.quicksave(path).is_empty(): return fail("Quicksave failed")
	var saved := Save.read_save(path, preload("res://scripts/lol2/dark_halls.gd").FORMAT)
	if not str(saved.error).is_empty(): return fail("Read save: " + str(saved.error))
	scene.quest_state.dark_halls_windows = {"opened": [], "done": false}
	windows.restore_from_quests()
	if scene.exits_open(): return fail("Reset state still open")
	error = scene.apply_save(saved.state)
	if not error.is_empty() or not windows.done() or windows.opened().size() != 7 or scene.prop_nodes[int(windows.source.orb.prop)].visible or int(scene.quest_state.monastery.globals.GV_LUTHERS_SOUL) != soul + 1: return fail("Reload lost the puzzle: %s" % error)
	var bad: Dictionary = saved.state.duplicate(true)
	bad.quests.dark_halls_windows = {"opened": [237, 238], "done": true}
	if preload("res://scripts/lol2/act_one_quest_state.gd").validate(bad.quests).is_empty(): return fail("Done with 2 windows accepted")
	print("PASS dark_halls_windows: exits shut, 6 windows by E + 1 by Spark from the dome floor, counter n/7, orb end once (soul %d -> %d, 18 grid SHADEs gone, orb hidden, exits open), 8th inert, kept across quicksave/quickload, bad state rejected" % [soul, soul + 1])
	quit(0)
