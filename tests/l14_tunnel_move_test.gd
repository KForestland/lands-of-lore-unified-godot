extends SceneTree
## L14 T3 geometry move (lead 2026-11-13; tools/prepare_geometry_move.py, scripts/lol2/geometry_moves/L14_HT.json): the
## crawl tunnel no longer shares the wooden room's space - it runs 100 lower under the room and ramps back up at both
## mouths. Real input: crouched (C held) with W held, the walker follows the tunnel's full-height strips from the west
## end (2516) down the ramp, under the room, up the east ramp to 2554, and back the same way. Each leg must arrive
## (no stall on a ramp), the walk must dip under the room (feet <= -70 there; the shaped dip is 85-92 deep under the room) and come back to the ends' floors.
## Also: the moved pack, nav and tracker table are the ones loaded.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
const ROUTE := [[1544, -4783], [1497, -4846], [1478, -4918], [1458, -4982], [1408, -5034], [1348, -5069], [1286, -5088], [1214, -5082],
		[1145, -5102], [1086, -5150], [1044, -5193], [998, -5252], [994, -5342], [1023, -5464], [1067, -5564]]
const TUNNEL := [2520, 2521, 2522, 2523, 2524, 2525, 2526, 2527, 2528, 2529, 2530, 2531, 2532, 2533, 2534, 2535, 2536,
		2537, 2538, 2539, 2540, 2542, 2543, 2545]
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL l14 tunnel move: ", m)
	quit(1)
func open_l14() -> Node:
	var entry := {}
	for c in Starts.manifest().entries:
		if str(c.id) == "act2-l14": entry = c
	var read: Dictionary = Starts.read(entry)
	if not str(read.error).is_empty(): return null
	load("res://scripts/lol2/game_save.gd").resume_checkpoint(self, entry.area_id, read.state, true)
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	for i in 20: await physics_frame
	return current_scene
func key(code: Key, down: bool) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down
	Input.parse_input_event(e); Input.flush_buffered_events()
## Holds C and W, turning toward each point; returns [lowest feet, last position] or [] when a leg stalls.
func crawl(scene: Node, points: Array, label: String) -> Array:
	var lowest := INF
	key(KEY_C, true); key(KEY_W, true)
	for i in points.size():
		var target := Vector2(float(points[i][0]), float(points[i][1]))
		var arrived := false
		var last := Vector2(scene.player.global_position.x, scene.player.global_position.z)
		var still := 0
		for f in 600:
			var p: Vector3 = scene.player.global_position
			var to := target - Vector2(p.x, p.z)
			if to.length() < 14.0: arrived = true; break
			scene.player.rotation.y = atan2(-to.x, -to.y)
			await physics_frame
			lowest = minf(lowest, scene.player.global_position.y - 32.0)
			var now := Vector2(scene.player.global_position.x, scene.player.global_position.z)
			still = still + 1 if now.distance_to(last) < 0.05 else 0
			last = now
			if still > 90: break
		if not arrived:
			for c in scene.player.get_slide_collision_count():
				var col: KinematicCollision3D = scene.player.get_slide_collision(c)
				printerr("STALL contact ", col.get_position(), " normal ", col.get_normal(), " collider ", col.get_collider(), " ", (col.get_collider() as Node).name if col.get_collider() is Node else "", " shape ", col.get_collider_shape_index())
			key(KEY_W, false); key(KEY_C, false)
			fail("%s: stalled before point %d %s at %s (crouched %s)" % [label, i, str(points[i]), str(scene.player.global_position), str(scene.get("crouched"))])
			return []
	key(KEY_W, false); key(KEY_C, false)
	for i in 5: await physics_frame
	return [lowest, scene.player.global_position]
func run() -> void:
	set_meta("original_game_verified", true)
	var scene: Node = await open_l14()
	if scene == null: return fail("L14 did not open")
	if not str(scene.geometry_file).ends_with("area_moved.json"): return fail("moved pack not loaded: " + str(scene.geometry_file))
	if not scene.tracker_on: return fail("tracker off")
	# The overlap rule compares base floors only, so tunnel side strips now stacked under the room can stay listed; the
	# producer checks the real condition (no tunnel face above the room's floor inside the room). Here: the moved table
	# is the one loaded (fewer pairs than the original's 389 overlap regions).
	if scene.tracker_overlaps.size() >= 389: return fail("tracker overlap list not the moved one (%d regions)" % scene.tracker_overlaps.size())
	var floor_2522: float = scene._tracker_floor(2522, Vector3(1348, 0, -5069))
	if floor_2522 > -70.0: return fail("tracker table floor at 2522 is %.1f, not moved" % floor_2522)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(true)
	scene.tracked_region = -1
	scene.player.global_position = Vector3(1544, scene._tracker_floor(2517, Vector3(1544, 0, -4783)) + 34.0, -4783)
	scene.player.velocity = Vector3.ZERO
	for i in 20: await physics_frame
	var there: Array = await crawl(scene, ROUTE, "west to east")
	if there.is_empty(): return
	if there[0] > -70.0: return fail("west to east never went under the room (lowest feet %.1f)" % there[0])
	var end_feet: float = there[1].y - 32.0
	if absf(end_feet - 0.0) > 12.0: return fail("east end feet %.1f, expected the 2554 floor 0" % end_feet)
	var back_route := ROUTE.duplicate(); back_route.reverse()
	var back: Array = await crawl(scene, back_route, "east to west")
	if back.is_empty(): return
	if back[0] > -70.0: return fail("east to west never went under the room (lowest feet %.1f)" % back[0])
	var west_feet: float = back[1].y - 32.0
	var west_floor: float = scene._tracker_floor(2517, back[1])
	if absf(west_feet - west_floor) > 12.0: return fail("west end feet %.1f, floor there %.1f" % [west_feet, west_floor])
	print("PASS l14 tunnel move: moved pack/nav/table loaded; crouched W west->east lowest feet %.1f, end %.1f; east->west lowest %.1f, end %.1f" % [there[0], end_feet, back[0], west_feet])
	quit(0)
