extends SceneTree
## L19 elevator cab: F5 while riding, then F9 (lead 2026-11-14, from the l19_dawn_curse_earned_test measurement: a save
## during the ride stores the cab's floor motion and the load resumes it). Real input from corridor 2010: E at prop 100,
## E at the Golden Doors, W into the cab 1943, which rides down; F5 when the cab is under -400, F9; the body must stay on
## the cab floor and ride on down to the bottom with it (a load does not fire the cab region's entry, which presses the lever). Test aids: start pose in 2010 (the robot's stand).
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL l19 cab ride save: ", m)
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
	# ride until the cab is well under way, F5 mid-ride, a few frames, then F9
	for t in 600:
		await physics_frame
		if int(prog.regions[1943][1]) <= -400: break
	var cab_at_save := int(prog.regions[1943][1])
	var feet_at_save: float = scene.player.global_position.y - 32.0
	print("RIDE before F5 motion %s elevator %s local4 %s" % [str(prog.floor_motion.get(1943, {})), str(scene.quest_state.get("l19_dawn_elevator")), str(prog.native.locals.get(4, null))])
	key(KEY_F5, true); await process_frame; key(KEY_F5, false)
	for t in 20: await physics_frame
	var old := current_scene
	key(KEY_F9, true); await process_frame; key(KEY_F9, false)
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene != old and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	scene = current_scene
	if scene == old: return fail("F9 did not reload (still the old map)")
	prog = scene.progression
	var creatures2 = scene.get("act2_creatures")
	if creatures2 is Node: creatures2.process_mode = Node.PROCESS_MODE_DISABLED
	print("RIDE after F9 elevator %s local4 %s" % [str(scene.quest_state.get("l19_dawn_elevator")), str(prog.native.locals.get(4, null))])
	print("RIDE F5 at cab %d feet %.1f; after F9 cab %d feet %.1f motion %s" % [cab_at_save, feet_at_save, int(prog.regions[1943][1]), scene.player.global_position.y - 32.0, str(prog.floor_motion.get(1943, {}))])
	var worst := 0.0
	for t in 900:
		await physics_frame
		var gap: float = absf(scene.player.global_position.y - 32.0 - float(prog.regions[1943][1]))
		worst = maxf(worst, gap)
		if t % 60 == 0: print("RIDE t %d cab %d feet %.1f on_floor %s" % [t, int(prog.regions[1943][1]), scene.player.global_position.y - 32.0, str(scene.player.is_on_floor())])
		if int(prog.regions[1943][1]) == -1000 and t > 30: break
	var feet: float = scene.player.global_position.y - 32.0
	print("RIDE end cab %d feet %.1f worst gap %.1f" % [int(prog.regions[1943][1]), feet, worst])
	if int(prog.regions[1943][1]) != -1000: return fail("after F9 the cab did not go on down to -1000 (it stopped at %d): the load turned the ride back" % int(prog.regions[1943][1]))
	if absf(feet - float(prog.regions[1943][1])) > 4.0: return fail("after F9 the body is not on the cab floor (feet %.1f, cab %d)" % [feet, int(prog.regions[1943][1])])
	if worst > 40.0: return fail("after F9 the body left the cab floor during the ride (worst gap %.1f)" % worst)
	print("PASS l19 cab ride save: F5 at cab %d, F9, the body rides the cab to %d (worst gap %.1f)" % [cab_at_save, int(prog.regions[1943][1]), worst])
	quit(0)
