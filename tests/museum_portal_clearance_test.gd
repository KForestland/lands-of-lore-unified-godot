extends SceneTree
## Region-blocker portal clearance (2026-10-31, lead's r12v finding): the Museum escape route enters region 1422 through the
## 24-unit opening between the corners of bit0 regions 1423 and 1424 at native (3036..3060, -1094); the player capsule
## (radius 15) could not pass two zero-thickness walls 24 units apart. region_blockers.gd now chamfers every portal corner
## (two walls of one blocked region meeting with different passable regions) by the body radius + 1. Here: the chamfers
## exist, the escape route's last legs (1021 -> opening -> 1422, plus off-centre entries) pass with the route walker's
## velocity method, crossing from 1019 / 1018 straight into 1423 / 1424 still stops at the wall, the player never counts as
## inside a blocked region, and the chamfer rebuilds when the body radius changes. Headless (no key input).
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func walk(scene, from: Vector3, target: Vector2, frames: int = 300) -> bool:
	scene.player.global_position = from; scene.player.velocity = Vector3.ZERO
	for i in 3: await physics_frame
	for step in frames:
		await physics_frame
		var offset := target - Vector2(scene.player.position.x, scene.player.position.z)
		if offset.length() < 3: return true
		var direction := offset.normalized(); var dt: float = scene.get_physics_process_delta_time()
		scene.player.velocity = Vector3(direction.x * minf(80, offset.length() / dt), -1 if scene.player.is_on_floor() else scene.player.velocity.y - 320 * dt, direction.y * minf(80, offset.length() / dt))
		if preload("res://scripts/lol2/walk_step.gd").try_step(scene.player, Vector3(scene.player.velocity.x, 0, scene.player.velocity.z) * dt): scene.player.velocity.x = 0; scene.player.velocity.z = 0
		scene.player.move_and_slide()
	return false
func run() -> void:
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	for i in 6: await process_frame
	for i in 4: await physics_frame
	if scene.has_method("set_development_mode"): scene.set_development_mode(false)
	scene.set_physics_process(false)
	var rb = scene.get_node_or_null("RegionBlockers")
	check(scene.region_blockers_enabled and rb != null and scene.region_blockers_attached == 551, "Museum blockers on, 551 static edges (%d)" % scene.region_blockers_attached)
	if rb == null: quit(1); return
	check(rb.player_radius() == 15.0 and rb.clearance == 16.0 and rb.chamfers > 0, "clearance = body radius 15 + 1, portal corners chamfered (%d chamfers, clearance %.1f)" % [rb.chamfers, rb.clearance])
	# Portal corners of the 1422 opening are chamfered: the wall ends no longer meet at (3036,-1094) / (3060,-1094).
	var faces: PackedVector3Array = rb.static_shape.shape.get_faces()
	var at_corner := 0
	for v in faces:
		if absf(v.z + 1094.0) < 0.01 and (absf(v.x - 3036.0) < 0.01 or absf(v.x - 3060.0) < 0.01): at_corner += 1
	check(at_corner == 0, "no wall vertex remains at the opening's corners (%d)" % at_corner)
	check(await walk(scene, Vector3(3051, 30, -982), Vector2(3048, -1094)), "escape route leg 1021 -> opening (3048,-1094) passes")
	check(await walk(scene, scene.player.global_position, Vector2(3040, -1216)), "leg opening -> 1422 (3040,-1216) passes")
	for x in [3042.0, 3054.0]:
		check(await walk(scene, Vector3(x, 30, -1000), Vector2(x, -1130)), "off-centre entry at x=%s passes" % x)
	check(not rb.inside_blocked(), "the player never counts as inside a blocked region on the way")
	# Straight into the blocked regions beside the opening: stopped at the wall, centre on the passable side within a radius.
	check(not await walk(scene, Vector3(3027, 30, -1060), Vector2(3027, -1140), 180) and scene.player.position.z > -1094.0 - 1.0, "1019 -> 1423 across the stub stops at the wall (z %.1f)" % scene.player.position.z)
	check(not await walk(scene, Vector3(3070, 30, -1060), Vector2(3070, -1140), 180) and scene.player.position.z > -1094.0 - 1.0, "1018 -> 1424 across the stub stops at the wall (z %.1f)" % scene.player.position.z)
	check(not rb.inside_blocked(), "still not inside a blocked region")
	# A different body radius rebuilds the chamfer on the next physics frame.
	var shape: CollisionShape3D = null
	for c in scene.player.get_children(): if c is CollisionShape3D: shape = c
	var before: int = rb.chamfers
	shape.shape.radius = 8.0
	await physics_frame; await physics_frame
	check(rb.clearance == 9.0 and rb.chamfers == before, "radius 8 rebuilds with clearance 9 (%.1f, %d chamfers)" % [rb.clearance, rb.chamfers])
	shape.shape.radius = 15.0
	await physics_frame; await physics_frame
	check(rb.clearance == 16.0, "back to clearance 16")
	# Every chamfer is a portal corner: same blocked region, different passable regions (data check on the pack).
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rb.path_for("L3_DH")))
	var cut: Array = rb.recessed_edges(data.edges, data.edges, 16.0).filter(func(e): return e.get("chamfer", false))
	check(cut.size() == rb.chamfers, "recessed_edges reproduces the chamfer count (%d vs %d)" % [cut.size(), rb.chamfers])
	var corners := {}
	for e in data.edges: for p in [e.a, e.b]: corners[Vector2i(roundi(p[0] * 2), roundi(p[1] * 2))] = corners.get(Vector2i(roundi(p[0] * 2), roundi(p[1] * 2)), []) + [e]
	var portal_corners := 0
	for k in corners:
		var pair: Array = corners[k]
		if pair.size() == 2 and int(pair[0].blocked) == int(pair[1].blocked) and int(pair[0].region) != int(pair[1].region): portal_corners += 1
	check(portal_corners == rb.chamfers, "chamfers == portal corners of the pack (%d vs %d)" % [portal_corners, rb.chamfers])
	print("Museum portal clearance: %d failures" % failures)
	if failures == 0: print("PASS museum portal clearance: %d portal corners chamfered by radius+1; the escape route passes the 24-unit 1422 opening headless; straight crossings into 1423/1424 still stop; rebuild on radius change" % rb.chamfers)
	quit(0 if failures == 0 else 1)
