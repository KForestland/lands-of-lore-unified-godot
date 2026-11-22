extends "res://tests/dark_halls_object_walk_input.gd"
func run() -> void:
	phase = "objects"
	if not await enter_from_monastery(): return
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dark_halls_objects_walk.json"))
	var requested: PackedStringArray = OS.get_environment("LOL2_DH_OBJECTS").split(",", false)
	if requested.is_empty(): return fail("LOL2_DH_OBJECTS required (e.g. slides:1041)")
	for objective in requested:
		phase = "objects_" + objective.replace(":", "_")
		var error_load: String = scene.quickload(OUT + "enter_arrival_quicksave.json")
		if not error_load.is_empty(): return fail("Earned arrival reload: " + error_load)
		var selected: Dictionary = {}
		for row in routes.routes:
			if str(row.family) + ":" + str(int(row.control)) == objective: selected = row
		if selected.is_empty(): return fail("Unknown objective " + objective)
		if not await walk_points(selected.points, objective): return
		var owner: Node3D = scene.slides if str(selected.family) == "slides" else scene.bookcases
		var id: String = str(int(selected.control))
		var definition: Dictionary = {}
		for row in owner.source.controls:
			if str(int(row.control)) == id: definition = row
		var point := Vector3(definition.center[0], definition.center[1], definition.center[2])
		if owner == scene.slides:
			look_toward(point)
			await physics_frame
			if owner.aimed() != id: return fail("Objective not aimed " + objective)
			await capture("closed")
			await tap(KEY_E)
			if not owner.is_open(id): return fail("Objective did not open " + objective)
			await capture("open")
			await f5()
			await tap(KEY_E)
			if owner.is_open(id): return fail("Objective did not close " + objective)
		else:
			if not owner.is_open(id): return fail("Route did not earn bookcase opening " + objective)
			await capture("walked_open")
			await f5()
		var saved_position: Vector3 = scene.player.position
		# Load the earlier arrival actually written in this run, so a no-op reload cannot pass.
		var earlier_error: String = scene.quickload(OUT + "enter_arrival_quicksave.json")
		if not earlier_error.is_empty() or owner.is_open(id): return fail("Earlier earned arrival did not restore closed object " + objective)
		await ensure_captured()
		await tap(KEY_F9)
		owner=scene.slides if str(selected.family)=="slides" else scene.bookcases
		for i in 3: await physics_frame
		if not owner.is_open(id) or scene.player.position.distance_to(saved_position) > 1.0: return fail("F9 did not restore earned open state and position " + objective)
		note("PASS earned object " + objective)
	receipt.passed = true
	write_receipt()
	print("PASS dark_halls_objects_earned: ", requested, "; pinned earned entry, live enemies, W/mouse/E and disk reload")
	quit(0)

func enter_from_monastery() -> bool:
	var expected := OS.get_environment("LOL2_DH_INPUT_SHA")
	if expected.is_empty():
		var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/broken-repair-earned-walk-checks.json"))
		expected = str(proof.get("output_sha256", "")) if proof is Dictionary else ""
	if expected.is_empty() or file_sha(INPUT) != expected: return fail("Earned monastery save missing or not the pinned witness")
	receipt.input = {"path": INPUT, "sha256": file_sha(INPUT)}
	change_scene_to_file(JUNGLE)
	scene = await wait_scene(JUNGLE)
	if scene == null: return fail("Jungle did not load")
	var error: String = scene.quickload(INPUT)
	if not error.is_empty(): return fail("Earned save load: " + error)
	for i in 10: await physics_frame
	var m: Node = scene.monastery
	if m.state().get("room", "") != "MENT": return fail("Earned save is not in the monastery hall: %s" % m.state().get("room", ""))
	var before: Dictionary = scene.area_handoff()
	receipt.before = {"soul": soul(), "items": before.inventory.collected.duplicate(), "health": health(), "mana": mana(), "globals": globals().duplicate()}
	# Hall -> cellar by the hall's own cellar hotspot (mouse click on the room view).
	var cellar: Control = null
	for hit in m.hotspots:
		if hit.get_meta("room", "") == "MENT" and hit.visible and Rect2(hit.position, hit.size).is_equal_approx(Rect2(0, 106, 87, 227)): cellar = hit
	if cellar == null: return fail("No visible MENT cellar hotspot")
	await click_control(cellar)
	for i in 5: await process_frame
	if m.state().get("room", "") != "MCEL": return fail("Cellar click did not enter MCEL (room %s)" % m.state().get("room", ""))
	await capture("cellar")
	for i in 60 * 120:
		await process_frame
		if not m.Speech.active(m.state().get("conversation", m.Speech.initial())): break
	if m.Speech.active(m.state().get("conversation", m.Speech.initial())): return fail("Cellar conversation did not end")
	var passage: Control = null
	for hit in m.hotspots:
		if hit.get_meta("room", "") == "MCEL" and hit.visible: passage = hit
	if passage == null: return fail("No visible MCEL hotspot1")
	var previous: int = scene.get_instance_id()
	await click_control(passage)
	scene = await wait_scene(HALLS, previous)
	if scene == null: return fail("Cellar hotspot1 did not load Dark Halls")
	for i in 20: await physics_frame
	var route: Node = scene.get_node("DarkHallsRoute")
	var arrival: Array = route.catalog().routes.jungle[0].arrival
	if Vector2(scene.player.position.x - arrival[0], scene.player.position.z - arrival[2]).length() > 2 or not scene.player.is_on_floor(): return fail("Not grounded at L7 entry1")
	if pop() == null or pop().bodies.size() != 51: return fail("Dark Halls population missing")
	if not pop().is_physics_processing() or not route.is_physics_processing() or not scene.is_physics_processing(): return fail("A Dark Halls host is not processing")
	var carried: Dictionary = scene.area_handoff()
	if carried.inventory.collected != before.inventory.collected or carried.quests.monastery.globals != before.quests.monastery.globals: return fail("Cellar handoff changed items or globals")
	await capture("arrival")
	last_health = -1
	trace_health("arrival")
	await ensure_captured()
	await f5()
	if not FileAccess.file_exists(DarkHalls.DEFAULT_PATH): return fail("F5 did not write the Dark Halls quicksave at arrival")
	receipt.arrival_save = {"sha256": file_sha(DarkHalls.DEFAULT_PATH)}
	copy_file(DarkHalls.DEFAULT_PATH, OUT + "enter_arrival_quicksave.json")
	return true
