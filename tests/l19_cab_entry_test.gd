extends SceneTree
## L19 Golden Doors 51/52 and the elevator cab (Grok robot/L19_BC/20261114_955dc4a-dawn3, lead 2026-11-14; DEVIATIONS row).
## The doors' native group 2166 swings leaves 51/52 (travel 16384) and, by opcode 196, drops the floor of the door sector
## 1932 (x 2493..2543, native floor 0 = ceiling 0: a closed slot) to -100 and raises its ceiling and 2010's to 40. The
## sector's two risers stand on its old floor: source wall 8646 (region 2010 edge 0, x 2493, -100..0) and 8552 (region
## 1931 edge 1, x 2543, -100..0). In the original they shrink to nothing as the floor comes down; in the port only the
## floor rode the opcode-196 deck, so 8646 stayed in 2010's collision and every stand stopped at x 2478 (capsule 15 off
## the wall). The deck now carries the risers on the sector's edges whose top is its old floor (act2_progression.gd).
## Real input (W held, mouse captured) from the robot's stand in 2010 to the cab 1943, after the doors' own group:
##  (a) E at prop 100 from corridor 2010 runs group 2166: region 1932's floor comes down to -100;
##  (b) the walk reaches the cab (x >= 2570, region 1943) and the body stands on the cab's floor (the cab may already be
##      riding its shaft: the elevator groups move 1943's floor by opcode 196);
##  (c) control: before the group the closed slot still holds the body in 2010 (x < 2493);
##  (d) the opened slot is closed on its null sides (z -943 / -824) and under its ceiling (0): no backdrop through it.
## Test aids: the start poses (the robot's stand in 2010) instead of the dawn walk to the doors.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL l19 cab entry: ", m)
	quit(1)
func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down
	Input.parse_input_event(e); Input.flush_buffered_events()
func walk_east(scene: Node, ticks: int) -> float:
	var east := -INF
	key(KEY_W, true)
	for t in ticks:
		var p: Vector3 = scene.player.global_position
		scene.player.rotation.y = atan2(-(2620.0 - p.x), -(-884.0 - p.z))
		await physics_frame
		east = maxf(east, scene.player.global_position.x)
	key(KEY_W, false)
	for t in 5: await physics_frame
	return east
func place(scene: Node, at: Vector3) -> void:
	scene.player.global_position = at; scene.player.velocity = Vector3.ZERO
	scene.last_collision_region = -1
	for t in 20: await physics_frame
func run() -> void:
	set_meta("original_game_verified", true)
	var entry := {}
	for c in Starts.manifest().entries:
		if str(c.id) == "act3-l19": entry = c
	load("res://scripts/lol2/game_save.gd").resume_checkpoint(self, entry.area_id, Starts.read(entry).state, true)
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	var scene: Node = current_scene
	for i in 30: await physics_frame
	if str(scene.get("area_id")) != "L19_BC": return fail("start opened " + str(scene.name))
	var creatures = scene.get("act2_creatures")
	if creatures is Node: creatures.process_mode = Node.PROCESS_MODE_DISABLED
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var prog = scene.progression
	# (c) control before the doors' group
	await place(scene, Vector3(2463, -100 + 32.5, -884))
	var closed: float = await walk_east(scene, 240)
	print("CAB (c) before group 2166: furthest east x %.1f (floor 1932 %d)" % [closed, int(prog.regions[1932][1])])
	if closed >= 2493.0: return fail("(c) the closed slot let the body east to x %.1f" % closed)
	# (a) E at prop 100 (the slot's control, kind 6 caller 20 -> group 2166), facing it from corridor 2010
	await place(scene, Vector3(2477, -100 + 32.5, -925))
	scene.player.rotation.y = atan2(-(2477.0 - 2477.0), -(-968.0 + 925.0))
	scene.camera.rotation.x = -0.6
	for t in 10: await physics_frame
	var aimed: String = str(prog.aimed_exit())
	key(KEY_E, true); await physics_frame; key(KEY_E, false)
	scene.camera.rotation.x = 0.0
	for t in 600:
		await physics_frame
		if int(prog.regions[1932][1]) == -100: break
	var result := {"aimed": aimed}
	print("RESULT ", str(result).left(600))
	print("CAB (a) E at prop 100 (aimed %s): floor 1932 %d" % [aimed, int(prog.regions[1932][1])])
	if int(prog.regions[1932][1]) != -100: return fail("(a) region 1932 floor %d after group 2166, want -100" % int(prog.regions[1932][1]))
	# (d) the opened slot's shell (lead 2026-11-14 after Grok cab2: open ceiling, backdrop through its sides)
	var space = scene.get_world_3d().direct_space_state
	var shell: Node = prog.get_node_or_null("FloorMotions/Slot1932")
	if shell == null: return fail("(d) no shell for the opened slot 1932")
	var hits := {}
	for probe in [["north side", Vector3(2518, -60, -884), Vector3(2518, -60, -1000)], ["south side", Vector3(2518, -60, -884), Vector3(2518, -60, -780)], ["ceiling", Vector3(2518, -60, -884), Vector3(2518, 100, -884)]]:
		var rq := PhysicsRayQueryParameters3D.create(probe[1], probe[2]); rq.hit_back_faces = true
		var hit: Dictionary = space.intersect_ray(rq)
		hits[probe[0]] = hit.get("position", null)
	print("CAB (d) slot shell hits ", hits)
	if hits["north side"] == null or absf(hits["north side"].z + 943.0) > 1.0: return fail("(d) the slot's north side is open (%s)" % str(hits["north side"]))
	if hits["south side"] == null or absf(hits["south side"].z + 824.0) > 1.0: return fail("(d) the slot's south side is open (%s)" % str(hits["south side"]))
	if hits["ceiling"] == null or absf(hits["ceiling"].y) > 1.0: return fail("(d) the slot's ceiling is open (%s)" % str(hits["ceiling"]))
	# the Golden Doors, opened by E as the robot did (AIM gold51 from 2454,-882)
	for door in [51, 52]:
		if int(prog.travel.get(door, 0)) == 16384: continue
		await place(scene, Vector3(2470, -100 + 32.5, -884))
		var dz := -854.0 if door == 51 else -914.0
		scene.player.rotation.y = atan2(-(2550.0 - 2470.0), -(dz + 884.0))
		for t in 6: await physics_frame
		key(KEY_E, true); await physics_frame; key(KEY_E, false)
		for t in 400:
			await physics_frame
			if int(prog.travel.get(door, 0)) == 16384: break
	print("CAB doors: travel 51 %s 52 %s" % [str(prog.travel.get(51)), str(prog.travel.get(52))])
	# (b) the walk into the cab
	await place(scene, Vector3(2463, -100 + 32.5, -884))
	var east: float = await walk_east(scene, 480)
	var p: Vector3 = scene.player.global_position
	var region: int = prog.region_at(p - Vector3(0, 31, 0))
	print("CAB (b) after group 2166: furthest east x %.1f, end %s region %d feet %.1f" % [east, str(p), region, p.y - 32.0])
	if east < 2570.0: return fail("(b) the body did not enter the cab: furthest east x %.1f (end %s)" % [east, str(p)])
	var cab := int(prog.regions[1943][1])
	print("CAB (b) cab floor now %d (motion %s)" % [cab, str(prog.floor_motion.get(1943, {}))])
	if absf(p.y - 32.0 - float(cab)) > 3.0: return fail("(b) feet %.1f, not on the cab floor %d" % [p.y - 32.0, cab])
	print("PASS l19 cab entry: closed slot holds at x %.1f; after E at prop 100 the body walks from 2010 into the cab to x %.1f" % [closed, east])
	quit(0)
