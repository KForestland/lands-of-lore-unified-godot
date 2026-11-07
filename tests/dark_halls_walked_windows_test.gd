extends SceneTree
## Dark Halls walkable slice (owner 2026-10-21: Dark Halls is Act 1). Earned R18 monastery save (LOL2_EARNED_SAVES):
## hall -> cellar (Rix) -> real click on MCEL hotspot1 -> Dark Halls arrival (L7 entry1) with the same inventory and
## quests; quicksave/quickload inside; grounded walk from the arrival to the slice exit (426 floor regions);
## the exit stays shut until the window puzzle is done, then takes the player back to Jungle entry6 with the state
## intact (soul +1 from the puzzle).
const Save = preload("res://scripts/lol2/jungle_save.gd")
const DarkHalls = preload("res://scripts/lol2/dark_halls.gd")
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL dark_halls_slice: ", message); quit(1); return false
## previous: instance id of the scene being left (0 for none); it may already be freed.
func wait_ready(previous: int) -> bool:
	for i in range(1500):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != previous and current_scene.get("ready_for_review"): return true
	return false
## No await here: hotspot1 changes the scene, which frees the control.
func click(control: Control) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed
		control.gui_input.emit(e)
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://capture"); root.get_texture().get_image().save_png("user://capture/dark_halls_" + name + ".png")
func run() -> void:
	var saves := OS.get_environment("LOL2_EARNED_SAVES")
	if saves.is_empty(): return fail("LOL2_EARNED_SAVES is required")
	var saved := Save.read_save(saves + "/act1_broken_repaired_monastery.json")
	if not str(saved.error).is_empty(): return fail("Earned save: " + str(saved.error))
	change_scene_to_file("res://scenes/lol2/jungle_walkthrough.tscn")
	if not await wait_ready(0): return fail("Jungle not ready")
	var jungle = current_scene
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var error: String = jungle.apply_save(saved.state)
	if not error.is_empty(): return fail("Apply earned save: " + error)
	for i in 10: await physics_frame
	var m = jungle.monastery
	if m.state().get("room", "") != "MENT": return fail("Earned save is not in the monastery hall")
	if not m.enter_room("MCEL"): return fail("Cellar not admitted by the earned save")
	for i in 3000:
		await process_frame
		if not m.Speech.active(m.state().get("conversation", m.Speech.initial())): break
	var passage: Control = null
	for hit in m.hotspots:
		if hit.get_meta("room", "") == "MCEL" and hit.visible: passage = hit
	if passage == null: return fail("No visible MCEL hotspot1")
	var before: Dictionary = jungle.area_handoff()
	click(passage)
	if not await wait_ready(jungle.get_instance_id()): return fail("Cellar hotspot1 did not load Dark Halls")
	var halls = current_scene
	if halls.scene_file_path != "res://scenes/lol2/dark_halls.tscn": return fail("Wrong scene " + halls.scene_file_path)
	for i in 20: await physics_frame
	var arrival: Array = halls.get_node("DarkHallsRoute").catalog().routes.jungle[0].arrival
	if Vector2(halls.player.position.x - arrival[0], halls.player.position.z - arrival[2]).length() > 2 or not halls.player.is_on_floor(): return fail("Not grounded at L7 entry1: %s" % halls.player.position)
	var carried: Dictionary = halls.area_handoff()
	if carried.quests.monastery.globals != before.quests.monastery.globals or carried.inventory.get("items") != before.inventory.get("items"): return fail("Handoff changed monastery globals or items")
	await capture("arrival")
	# Original Rats/SHADEs hosted, state in the quests (travels with saves and handoffs).
	var creatures = halls.get("creatures")
	if creatures == null or creatures.bodies.size() != 51 or not halls.quest_state.has("dark_halls_population"): return fail("Dark Halls creatures missing: %s" % [creatures.bodies.size() if creatures != null else -1])
	creatures.set_physics_process(false); creatures.set_process(false)
	# Native scenery boxes (static_collision_L7_DH.json) enclose their own drawn faces.
	if halls.solid_bodies.size() < 80: return fail("Dark Halls scenery boxes missing: %d" % halls.solid_bodies.size())
	var area: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/dark_halls/area.json"))
	var centres: Dictionary = {}
	for f in area.faces:
		if f.kind == "movable" and halls.solid_bodies.has(int(f.source_index)):
			if not centres.has(int(f.source_index)): centres[int(f.source_index)] = []
			for q in f.points: centres[int(f.source_index)].append(Vector3(q[0], q[1], q[2]))
	var misplaced: Array = []
	for id in centres:
		var mid := Vector3.ZERO
		for q in centres[id]: mid += q
		mid /= float(centres[id].size())
		var body: StaticBody3D = halls.solid_bodies[id]
		var inside := false
		for shape in body.get_children():
			var local: Vector3 = (body.global_transform * shape.transform).affine_inverse() * mid
			var half: Vector3 = shape.shape.size / 2.0 + Vector3(12, 400, 12)
			if absf(local.x) <= half.x and absf(local.z) <= half.z: inside = true
		if not inside: misplaced.append(id)
	if misplaced.size() > 0: return fail("Scenery boxes off their faces: %s" % [misplaced])
	var box_count: int = halls.solid_bodies.size()
	# Quicksave/quickload inside Dark Halls.
	var path := "user://tests/dark_halls_slice.json"
	error = halls.quicksave(path)
	if not error.is_empty(): return fail("Quicksave: " + error)
	var start: Vector3 = halls.player.position
	halls.player.position += Vector3(0, 0, -40)
	var reread := Save.read_save(path, DarkHalls.FORMAT)
	if not str(reread.error).is_empty(): return fail("Read Dark Halls save: " + str(reread.error))
	error = halls.apply_save(reread.state)
	if not error.is_empty() or halls.player.position.distance_to(start) > 1.0: return fail("Quickload did not restore the position: %s" % error)
	# Grounded walk to the slice exit; the route host stays off until the end.
	var route = halls.get_node("DarkHallsRoute")
	route.set_physics_process(false)
	halls.set_physics_process(false)
	var walk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dark_halls_walk_path.json"))
	for k in walk.points.size():
		var target := Vector2(walk.points[k][0], walk.points[k][1])
		var reached := false
		for f in 240:
			var p: Vector3 = halls.player.position
			var d := Vector2(target.x - p.x, target.y - p.z)
			if d.length() < 6: reached = true; break
			# The host's own grounded movement (sprint speed, step-up, gravity), as the W key uses it.
			halls.move_grounded(Vector3(d.normalized().x, 0, d.normalized().y), 1.0 / 60.0, true)
			await physics_frame
		if not reached: return fail("Walk stuck before waypoint %d/%d (region %s) at %s" % [k, walk.points.size(), walk.regions[mini(k + 1, walk.regions.size() - 1)], halls.player.position])
	if not route.inside_route(route.routes[route.routes.size() - 1]): return fail("Walk ended outside the slice exit")
	await capture("exit")
	var entry6: Array = route.routes[0].arrival
	# Walk the dome perimeter and use normal E input; never set a window state directly.
	var exit_position: Vector3 = halls.player.position
	for control in [246, 247, 251, 250, 249, 248, 237]:
		var window: Dictionary = halls.windows.by_control[control]
		var center: Vector3 = halls.windows._vec(window.center)
		var target: Vector3 = center + halls.windows._inward(window) * 70.0
		if not await walk_to(halls, Vector2(target.x, target.z), 900): return fail("Window walk blocked at %d pos=%s" % [control, halls.player.position])
		halls.camera.look_at(center)
		await physics_frame
		if halls.windows.aimed_window() != control: return fail("Window %d not aimed after walk" % control)
		await press_e()
		if not control in halls.windows.opened(): return fail("E failed on walked window %d" % control)
		print("WALKED_WINDOW ", control, " position=", halls.player.position)
	if not await walk_to(halls, Vector2(exit_position.x,exit_position.z), 1200): return fail("Return to exit blocked")
	halls.set_physics_process(true)
	route.set_physics_process(true)
	if not halls.exits_open(): return fail("Exits still shut after the puzzle")
	if not await wait_ready(halls.get_instance_id()): return fail("Slice exit did not return to the Jungle")
	var back = current_scene
	for i in 20: await physics_frame
	if back.scene_file_path != "res://scenes/lol2/jungle_walkthrough.tscn" or Vector2(back.player.position.x - entry6[0], back.player.position.z - entry6[2]).length() > 2 or not back.player.is_on_floor(): return fail("Not grounded at Jungle entry6: %s" % back.player.position)
	var expected: Dictionary = before.quests.monastery.globals.duplicate()
	expected.GV_LUTHERS_SOUL = int(expected.get("GV_LUTHERS_SOUL", preload("res://scripts/lol2/shared_global_defaults.gd").initial_value("GV_LUTHERS_SOUL"))) + 1
	var got: Dictionary = back.area_handoff().quests.monastery.globals
	if got.size() != expected.size(): return fail("Return changed the monastery global keys")
	for key in expected:
		if not got.has(key) or float(got[key]) != float(expected[key]): return fail("Return global %s = %s, expected the earned value plus the window soul +1 (%s)" % [key, got.get(key), expected[key]])
	if not bool(back.quest_state.get("dark_halls_windows", {}).get("done", false)): return fail("Window puzzle state lost on the return")
	print("PASS dark_halls_walked_windows: earned cellar hotspot1 -> L7 entry1 grounded with the same items/globals, 51 creatures (31 Rats, 19 Shades, Rix) in the quests, %d native scenery boxes on their faces, quicksave/quickload, %d-waypoint grounded walk to the slice exit, seven windows reached on foot and opened with E, return to Jungle entry6 grounded" % [box_count, walk.points.size()])
	quit(0)

func walk_to(halls: Node3D, target: Vector2, frames: int) -> bool:
	for frame in frames:
		var position: Vector3 = halls.player.position
		var difference := target - Vector2(position.x, position.z)
		if difference.length() < 6.0: return true
		halls.move_grounded(Vector3(difference.x, 0, difference.y).normalized(), 1.0 / 60.0, true)
		await physics_frame
	return false

func press_e() -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_E; event.physical_keycode = KEY_E; event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events()
		await process_frame
