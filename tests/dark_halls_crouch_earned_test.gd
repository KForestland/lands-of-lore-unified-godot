extends "res://tests/dark_halls_earned_detour_test.gd"
func run() -> void:
	phase = "crouch"
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
	var walk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dark_halls_walk_path.json"))
	if not await walk_points(walk.points, "crawl_approach", 6.0, 0, 12): return
	if not await walk_to(Vector2(-3025, -2603.5), 5, 3600, "crawl_east"): return
	await capture("standing_approach")
	# Native region65 has floor116/ceiling156 (40 clearance): Human46 cannot enter; crouched32 can.
	if not await walk_to(Vector2(-3067, -2603.5), 2, 600, "standing_blocked", true, true): return
	if scene.player.position.x < -3050: return fail("Standing Human entered native40-height crawlspace")
	set_key(KEY_C, true)
	for i in 3: await physics_frame
	if not scene.crouched: return fail("Physical C did not crouch")
	if not await walk_to(Vector2(-3067, -2603.5), 1, 600, "crawl_under"): return
	set_key(KEY_C, false)
	for i in 12: await physics_frame
	if not scene.crouched: return fail("Stood up inside native40-height header")
	await capture("under_header")
	await f5()
	set_key(KEY_C, true)
	if not await walk_to(Vector2(-3120, -2603.5), 4, 600, "crawl_west"): return
	set_key(KEY_C, false)
	for i in 12: await physics_frame
	if scene.crouched: return fail("Did not stand after clearing header")
	await capture("cleared_header")
	# Save was earned beneath the header; reload with C released must fit the player back under it.
	var reload_error: String = scene.quickload(DarkHalls.DEFAULT_PATH)
	if not reload_error.is_empty(): return fail("Low-header reload: " + reload_error)
	for i in 3: await physics_frame
	if not scene.crouched: return fail("Reload rebuilt standing Human inside native40-height header")
	var collision: CollisionShape3D = scene.player.get_child(0) as CollisionShape3D
	if not is_equal_approx(float(collision.shape.height), 32): return fail("Reloaded crouch did not fit32")
	await capture("reloaded_under_header")
	if not await walk_to(Vector2(-3120, -2603.5), 4, 600, "reload_walk_clear"): return
	for i in 12: await physics_frame
	if scene.crouched: return fail("Reloaded player did not stand after clearing header")
	receipt.passed = true
	write_receipt()
	print("PASS dark_halls_crouch_earned: pinned monastery -> cellar -> live input walk; standing blocked, C crawls native40-height region65, release under header refuses stand, release beyond header stands; no geometry changes")
	quit(0)
