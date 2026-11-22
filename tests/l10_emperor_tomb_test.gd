extends SceneTree
## L10 Emperor tomb floor lowering (lead 2026-11-14; Grok grok_research/L10_SHOWTHROUGH_FRAMES_20261113.md, poses box127,
## box125, door143, remains; DEVIATIONS row). The tomb hall (floor -50, ceilings 50..200) shares its plan with the yard
## (floor 0), so the eye (feet + 56) stood 6 above the yard floor. tools/prepare_geometry_move.py zone EMP (floor_lower):
## its 33 floors at -50 go to -66, ceilings stay, every wall point at -50 on a moved edge moves with them, doors 143/175
## stretch to the new floor. The colour box tops (-30) get a player-only fence (tools/prepare_l10_boundary_packet.py).
## Checks, from the C-15 Cemetery start:
##  (a) the moved pack is live; floors under the hall, the remains and door 143 are at -66, the box room and passage are
##      not moved, and the catacomb ceiling (-75) still lies under the hall;
##  (b) no wall point at -50 is left on a moved edge (no slit, no lip), and the 22 boundary keys of moved walls collide;
##  (c) doors 143/175 reach the new floor (drawn faces and solid boxes), their tops stay at the kept ceiling (50);
##  (d) real input (W held) from the slab passage at -90 through the box room (-80) up into the hall (-66) and on to the
##      inner doors: the lowered floor is taken without a lip, and the eye there is under the yard floor;
##  (e) real input (W held, with jumps) at each colour box from the floor: the feet never reach the box top (-30);
##  (f) the Emperor's remains are still reachable from the lowered floor (l10_emperor reachable band follows the move);
##  (g) old saves: feet -50 inside the tomb are carried to -66; feet 5 on the yard over the tomb are not.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
const GM = preload("res://scripts/lol2/geometry_move.gd")
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL l10 emperor tomb: ", m)
	quit(1)
func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down
	Input.parse_input_event(e); Input.flush_buffered_events()
func face(scene: Node, to: Vector2) -> void:
	var p: Vector3 = scene.player.global_position
	scene.player.rotation.y = atan2(-(to.x - p.x), -(to.y - p.z))
func place(scene: Node, at: Vector3) -> void:
	scene.player.global_position = at; scene.player.velocity = Vector3.ZERO
	scene.progression.current_region = -1
	scene.progression.current_region = scene.progression.region_at(at - Vector3(0, 31, 0))
	for t in 20: await physics_frame
func down(space, x: float, y: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, y, z), Vector3(x, y - 300.0, z)); q.hit_back_faces = true
	var r: Dictionary = space.intersect_ray(q)
	return r.position.y if not r.is_empty() else -INF
func run() -> void:
	set_meta("original_game_verified", true)
	var entry := {}
	for c in Starts.manifest().entries:
		if str(c.id) == "act2-l10": entry = c
	load("res://scripts/lol2/game_save.gd").resume_checkpoint(self, entry.area_id, Starts.read(entry).state, true)
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	var scene: Node = current_scene
	for i in 30: await physics_frame
	if str(scene.get("area_id")) != "L10_DC": return fail("start opened " + str(scene.name))
	var creatures = scene.get("act2_creatures")
	if creatures is Node: creatures.process_mode = Node.PROCESS_MODE_DISABLED
	var spec: Dictionary = GM.spec("L10_DC")
	# (a)
	if not str(scene.geometry_file).ends_with("area_moved.json") or spec.is_empty() or str(spec.zones[0].zone) != "EMP": return fail("(a) moved pack not live: " + str(scene.geometry_file))
	if spec.moved.size() != 33: return fail("(a) moved regions %d" % spec.moved.size())
	var space = scene.player.get_world_3d().direct_space_state
	var floors := {"hall 3819": [3207.0, -1450.0, -66.0], "remains 3789": [3207.0, -1277.0, -66.0], "door 3811": [3205.0, -1358.0, -66.0],
		"west hall 3862": [3110.0, -1650.0, -66.0], "box room 3883": [3207.0, -1650.0, -80.0]}
	for name in floors:
		var f: Array = floors[name]
		var y := down(space, f[0], -12.0, f[1])
		if absf(y - float(f[2])) > 1.0: return fail("(a) floor under %s at %.1f, want %.0f" % [name, y, f[2]])
	var cat := down(space, 3330.0, -67.0, -1360.0)
	if cat > -74.0 or cat < -76.0: return fail("(a) under the hall at (3330,-1360) the next surface is %.1f, want the catacomb ceiling -75" % cat)
	print("TOMB (a) hall/remains/door floors -66, box room -80, catacomb ceiling %.1f under the hall" % cat)
	# (b)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
	var nav: Array = scene.progression.regions
	var edges: Array = []
	for r in spec.moved:
		var q: Array = spec.corner_quads[str(int(r))]
		for i in q.size(): edges.append([Vector2(q[i][0], q[i][1]), Vector2(q[(i + 1) % q.size()][0], q[(i + 1) % q.size()][1])])
	var left := 0
	var extended := 0
	for f: Dictionary in data.faces:
		if str(f.get("kind", "")) not in ["wall", "source_wall"]: continue
		for p in f.points:
			var on := false
			for e in edges:
				if Geometry2D.get_closest_point_to_segment(Vector2(p[0], p[2]), e[0], e[1]).distance_to(Vector2(p[0], p[2])) < 0.5: on = true; break
			if not on: continue
			if absf(float(p[1]) + 50.0) < 0.01: left += 1
			if absf(float(p[1]) + 66.0) < 0.01: extended += 1
	if left != 0: return fail("(b) %d wall points still at -50 on moved edges" % left)
	if scene.height_boundary_keys.size() != 3532: return fail("(b) boundary keys %d, want 3532" % scene.height_boundary_keys.size())
	var moved_keys := 0
	for k in spec.key_moves:
		if scene.height_boundary_keys.has(str(k)): moved_keys += 1
	if moved_keys != 22: return fail("(b) moved boundary keys selected %d, want 22" % moved_keys)
	print("TOMB (b) 0 wall points left at -50 on moved edges, %d at -66; 22 moved boundary keys selected" % extended)
	# (c)
	var assemblies: Array = []
	for n in scene.find_children("StaticAssemblies_L10_DC", "", true, false): assemblies.append(n)
	if assemblies.is_empty(): return fail("(c) no static assemblies host")
	for id in [143, 175]:
		var lo := INF; var hi := -INF
		for f in assemblies[0].data.faces:
			if int(f.assembly) != id: continue
			for p in f.points: lo = minf(lo, float(p[1])); hi = maxf(hi, float(p[1]))
		if absf(lo + 66.0) > 0.01 or absf(hi - 50.0) > 0.01: return fail("(c) door %d spans %.1f..%.1f, want -66..50" % [id, lo, hi])
		var box: Dictionary = preload("res://scripts/lol2/static_assemblies.gd").carried_box("L10_DC", id, JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L10_DC.json")).boxes[str(id)])
		if absf(float(box.h) + 66.0) > 0.01 or absf(float(box.h) + float(box.height) - 50.0) > 0.01: return fail("(c) door %d solid box %s" % [id, str(box)])
	print("TOMB (c) doors 143/175 span -66..50 (faces and solid boxes)")
	# (d)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await place(scene, Vector3(3207, -90 + 32.5, -1950))
	var route := [Vector2(3207, -1800), Vector2(3207, -1680), Vector2(3130, -1660), Vector2(3110, -1600), Vector2(3110, -1460), Vector2(3207, -1450), Vector2(3207, -1400)]
	var i := 0
	key(KEY_W, true)
	for t in 900:
		var p: Vector3 = scene.player.global_position
		if i < route.size() - 1 and Vector2(p.x, p.z).distance_to(route[i]) < 8.0: i += 1
		if i == route.size() - 1 and Vector2(p.x, p.z).distance_to(route[i]) < 8.0: break
		face(scene, route[i])
		await physics_frame
	key(KEY_W, false)
	for t in 10: await physics_frame
	var end: Vector3 = scene.player.global_position
	var eye: float = scene.camera.global_position.y
	print("TOMB (d) walked from the passage to %s (point %d/%d), feet %.1f, eye %.1f" % [str(end), i + 1, route.size(), end.y - 32.0, eye])
	if Vector2(end.x, end.z).distance_to(route[route.size() - 1]) > 12.0: return fail("(d) the walk into the hall stopped at %s (next point %s)" % [str(end), str(route[i])])
	if absf(end.y - 32.0 + 66.0) > 2.0: return fail("(d) feet in the hall %.1f, want -66" % (end.y - 32.0))
	if eye >= 0.0: return fail("(d) the eye in the hall at %.1f stands above the yard floor" % eye)
	# (e)
	var tops := {"127": Vector2(3017, -1560), "126": Vector2(3207, -1560), "125": Vector2(3378, -1560)}
	for box in tops:
		var at: Vector2 = tops[box]
		await place(scene, Vector3(at.x, -80 + 32.5, -1615))
		var high := -INF
		key(KEY_W, true)
		for t in 240:
			face(scene, at)
			if t % 40 == 20: key(KEY_SPACE, true)
			if t % 40 == 24: key(KEY_SPACE, false)
			await physics_frame
			if scene.player.is_on_floor(): high = maxf(high, scene.player.global_position.y - 32.0)
		key(KEY_W, false); key(KEY_SPACE, false)
		for t in 10: await physics_frame
		print("TOMB (e) box %s: highest grounded feet %.1f" % [box, high])
		if high > -45.0: return fail("(e) the body stood on colour box %s (feet %.1f)" % [box, high])
	# (f)
	await place(scene, Vector3(3207, -66 + 32.5, -1270))
	var emperor: Node = scene.get_node_or_null("L10Emperor")
	if emperor == null: return fail("(f) no L10Emperor node")
	var p0: Vector3 = scene.player.global_position
	var low := -30.0 + GM.delta("L10_DC", 3789, p0.x, p0.z)
	if not (p0.y >= low and p0.y <= 0.0): return fail("(f) remains band: body y %.1f outside %.1f..0" % [p0.y, low])
	print("TOMB (f) remains band %.1f..0 holds the body at y %.1f on the lowered floor" % [low, p0.y])
	# (g)
	var snap: Dictionary = preload("res://scripts/lol2/act2_save.gd").snapshot_host(scene)
	snap.player.erase("geometry_move"); snap.player.erase("region")
	snap.player.position = [3207.0, -50.0 + 32.0, -1277.0]
	var err: String = scene.apply_save(snap)
	if not err.is_empty(): return fail("(g) apply old tomb save: " + err)
	var carried: float = scene.player.global_position.y - 32.0
	snap.player.position = [3207.0, 5.0 + 32.0, -1277.0]
	err = scene.apply_save(snap)
	if not err.is_empty(): return fail("(g) apply old yard save: " + err)
	var yard: float = scene.player.global_position.y - 32.0
	print("TOMB (g) old save feet -50 in the tomb -> %.1f; feet 5 on the yard -> %.1f" % [carried, yard])
	if absf(carried + 66.0) > 0.5: return fail("(g) old tomb save not carried (%.1f)" % carried)
	if absf(yard - 5.0) > 0.5: return fail("(g) old yard save moved (%.1f)" % yard)
	print("PASS l10 emperor tomb: hall floors -66 (eye %.1f, catacomb ceiling %.1f below), no wall left at -50, doors 143/175 -66..50, walk from the passage into the hall, box tops kept clear, remains reachable, old saves carried only from the tomb" % [eye, cat])
	quit(0)
