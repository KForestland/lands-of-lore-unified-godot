extends SceneTree
## L19 Dawn-shaft cab, bottom (lead 2026-11-14, Grok robot/L19_BC/20261114_da81ea3-dawn: at -1000 the walk east toward
## Dawn stopped at (2673, -958, -881) in the cab, 'overlap RegionBlockers'). The ride down (group 1762) sets blocker bit 0
## on the ring 1935-1942 (strip 1940 lies between the cab and the bottom hall 2737); the end group 1200 clears it and opens
## the bottom doors 53/54. Adapter l19_cab_arrival runs the end group when the cab's floor reaches its target.
## Real input from corridor 2010: E at prop 100, E at the Golden Doors, W into the cab, which rides down; at the bottom W
## east toward Dawn (2802, -882): the body leaves the cab past x 2700. Test aids: start pose in 2010 (the robot's stand).
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL l19 cab bottom exit: ", m)
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
	var east: float = await walk_east(scene, 300)
	var p: Vector3 = scene.player.global_position
	var region: int = prog.region_at(p - Vector3(0, 31, 0))
	print("CAB (b) after group 2166: furthest east x %.1f, end %s region %d feet %.1f" % [east, str(p), region, p.y - 32.0])
	if east < 2570.0: return fail("(b) the body did not enter the cab: furthest east x %.1f (end %s)" % [east, str(p)])
	if region != 1943: return fail("did not reach the cab (region %d, x %.1f)" % [region, east])
	if region != 1943: return fail("did not reach the cab (region %d, x %.1f)" % [region, east])
	for t in 1200:
		await physics_frame
		if int(prog.regions[1943][1]) == -1000 and int((prog.floor_motion.get(1943, {"remaining": 0}) as Dictionary).remaining) == 0: break
	for t in 30: await physics_frame
	print("BOTTOM cab %d feet %.1f doors 53 %s 54 %s arrival %s" % [int(prog.regions[1943][1]), scene.player.global_position.y - 32.0, str(prog.travel.get(53)), str(prog.travel.get(54)), str(prog.route_log.filter(func(r): return str(r.get("object")) == "cab_arrival"))])
	if int(prog.regions[1943][1]) != -1000: return fail("the cab did not reach -1000 (%d)" % int(prog.regions[1943][1]))
	var far := -INF
	key(KEY_W, true)
	for t in 600:
		var p2: Vector3 = scene.player.global_position
		scene.player.rotation.y = atan2(-(2802.0 - p2.x), -(-882.0 - p2.z))
		await physics_frame
		far = maxf(far, scene.player.global_position.x)
	key(KEY_W, false)
	var end2: Vector3 = scene.player.global_position
	print("BOTTOM walk east: furthest x %.1f end %s region %d" % [far, str(end2), prog.region_at(end2 - Vector3(0, 31, 0))])
	if far < 2700.0: return fail("the body did not leave the cab at the bottom: furthest x %.1f (end %s)" % [far, str(end2)])
	print("PASS l19 cab bottom exit: the cab arrives at -1000, its end group opens the way, the body walks east to x %.1f" % far)
	quit(0)
