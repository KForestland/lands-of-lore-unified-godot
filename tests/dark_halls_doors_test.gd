extends SceneTree
## Dark Halls doors (prepare_dark_halls_doors.py): both leaves shut and solid at the start (a scenery-layer ray across
## the doorway hits the leaf); E in front of a door swings it open on its native hinge (the ray passes) and E again
## shuts it. Door 57's trap: a grounded player in region1338 slams and locks it and brings SHADE 73 beside the trap;
## E on the locked door leaves it shut; SHADE 73's death unlocks it and E opens it. State survives quicksave/quickload.
const Save = preload("res://scripts/lol2/jungle_save.gd")
const Assemblies = preload("res://scripts/lol2/static_assemblies.gd")
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL dark_halls_doors: ", message); quit(1); return false
func press_e() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = KEY_E; e.physical_keycode = KEY_E; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
		await process_frame
## Ray across the shut leaf, along the door's normal, at mid height (scenery layer only).
func blocked(scene, row: Dictionary) -> bool:
	var origin := Vector3(row.origin[0], row.origin[1], row.origin[2]) + Vector3(0, row.size[1] / 2.0, 0)
	var yaw := -float(row.heading) / 65536.0 * TAU
	var normal := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	var query := PhysicsRayQueryParameters3D.create(origin - normal * 30.0, origin + normal * 30.0, Assemblies.SCENERY_LAYER)
	return not scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func stand(scene, row: Dictionary) -> void:
	var origin := Vector3(row.origin[0], row.origin[1], row.origin[2])
	var yaw := -float(row.heading) / 65536.0 * TAU
	var normal := Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	scene.player.global_position = origin + normal * 70.0 + Vector3(0, 32, 0)
	scene.player.velocity = Vector3.ZERO
	await physics_frame
	scene.camera.look_at(origin + Vector3(0, 40, 0))
	await physics_frame
func settle() -> void:
	for i in 80: await physics_frame
func run() -> void:
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for i in range(1500):
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	var scene = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("Dark Halls not ready")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var pop = scene.creatures
	pop.set_physics_process(false); pop.set_process(false)
	var doors = scene.doors
	if doors == null or doors.leaves.size() != 2: return fail("Door host missing")
	scene.set_physics_process(false)
	for row in doors.source.doors:
		var id := str(int(row.movable))
		if not blocked(scene, row): return fail("Door %s not solid when shut" % id)
		await stand(scene, row)
		if doors.aimed() != id: return fail("Door %s not aimed" % id)
		await press_e()
		await settle()
		if not doors.is_open(id) or absf(doors.leaves[id].hinge.rotation.y) < deg_to_rad(100.0): return fail("E did not swing door %s open (%.2f)" % [id, doors.leaves[id].hinge.rotation.y])
		if blocked(scene, row): return fail("Door %s still blocks when open" % id)
		await press_e()
		await settle()
		if doors.is_open(id) or absf(doors.leaves[id].hinge.rotation.y) > 0.01 or not blocked(scene, row): return fail("E did not shut door %s" % id)
	# Door 57 trap.
	var t: Dictionary = doors.source.trap
	var door57: Dictionary = doors.source.doors[1]
	await stand(scene, door57)
	await press_e()
	await settle()
	if not doors.is_open("57"): return fail("Door 57 did not open before the trap")
	var mid := Vector2.ZERO
	for q in t.polygon: mid += Vector2(q[0], q[1])
	mid /= float(t.polygon.size())
	scene.player.global_position = Vector3(mid.x, float(t.floor) + 32.0, mid.y)
	scene.player.velocity = Vector3.ZERO
	scene.set_physics_process(true)
	for i in 30: await physics_frame
	scene.set_physics_process(false)
	if not bool(doors.state().trap) or not doors.is_locked("57") or doors.is_open("57"): return fail("Trap did not slam and lock door 57")
	var shade: Array = pop.state.actors[t.actor].position
	if Vector2(shade[0] - t.actor_to[0], shade[2] - t.actor_to[1]).length() > 1.0: return fail("SHADE 73 not moved beside the trap: %s" % [shade])
	await settle()
	if not blocked(scene, door57): return fail("Slammed door 57 not solid")
	await stand(scene, door57)
	await press_e()
	await settle()
	if doors.is_open("57"): return fail("Locked door 57 opened")
	var path := "user://tests/dark_halls_doors.json"
	if not scene.quicksave(path).is_empty(): return fail("Quicksave failed")
	pop.receive_damage(t.actor, 999, true)
	for i in 3: await physics_frame
	if doors.is_locked("57"): return fail("SHADE 73's death did not unlock door 57")
	await press_e()
	await settle()
	if not doors.is_open("57"): return fail("Unlocked door 57 did not open with E")
	var saved := Save.read_save(path, preload("res://scripts/lol2/dark_halls.gd").FORMAT)
	if not str(saved.error).is_empty(): return fail("Read save: " + str(saved.error))
	var error: String = scene.apply_save(saved.state)
	if not error.is_empty() or not doors.is_locked("57") or doors.is_open("57") or absf(doors.leaves["57"].hinge.rotation.y) > 0.01: return fail("Reload lost the locked door: %s" % error)
	var bad: Dictionary = saved.state.quests.duplicate(true)
	bad.dark_halls_doors["57"] = {"open": true, "locked": true}
	if preload("res://scripts/lol2/act_one_quest_state.gd").validate(bad).is_empty(): return fail("Open and locked door accepted")
	print("PASS dark_halls_doors: doors 56/57 solid when shut, E swings each open on its hinge and shut again; region1338 slams and locks door 57 and brings SHADE 73 beside the trap; locked door stays shut; SHADE 73's death unlocks it; kept across quicksave/quickload; bad state rejected")
	quit(0)
