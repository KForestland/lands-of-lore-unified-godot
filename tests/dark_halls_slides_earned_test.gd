extends "res://tests/dark_halls_earned_detour_test.gd"
func run() -> void:
	phase = "slides"
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
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dark_halls_slides_walk.json"))
	var selected: Dictionary = {}
	for row in routes.routes:
		if int(row.control) == 1015: selected = row
	# The route crosses bookcase59, now physically solid. Earn its opening on approach.
	if not await walk_points(selected.points, "slide1015", 6.0, 0, 31): return
	if not await walk_to(Vector2(-2528, -3822), 6, 3600, "slide_route_shelf59"): return
	look_toward(Vector3(-2528, 124, -3892))
	await physics_frame
	if scene.bookcases.aimed() != "59": return fail("Route shelf59 not aimed")
	await tap(KEY_E)
	if not scene.bookcases.is_open("59"): return fail("Route shelf59 did not open")
	if not await walk_points(selected.points, "slide1015", 6.0, 31): return
	var slides: Node3D = scene.slides
	var point := Vector3(-1581, 352, -2649.5)
	look_toward(point)
	await physics_frame
	if slides.aimed() != "1015": return fail("Slide1015 not aimed from earned approach")
	await capture("slide1015_closed")
	await tap(KEY_E)
	if not slides.is_open("1015"): return fail("E did not open slide1015")
	await capture("slide1015_open")
	await f5()
	await tap(KEY_E)
	if slides.is_open("1015"): return fail("E did not close slide1015")
	var error_reload: String = scene.quickload(DarkHalls.DEFAULT_PATH)
	if not error_reload.is_empty() or not slides.is_open("1015"): return fail("Reload did not restore slide1015")
	receipt.passed = true
	write_receipt()
	print("PASS dark_halls_slides_earned: pinned monastery save, cellar clicks, live combat and walked floor route, slide1015 E toggle, captures and disk reload; other five slides not earned yet")
	quit(0)
