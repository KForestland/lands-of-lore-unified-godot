extends SceneTree
## G-05 region tracker on L14 (act2_map TRACKER_AREAS, ledger 0641): at r36/3890 (region 3890's quad overlaps r36 at
## floor -80) what is solid and where portal drawing starts depend on the region the walker is tracked in.
## (a) tracked in 3890, walking east along z -3520 (3890's east edge is at x 3331 there) into the overlap: not refused, stays 3890, drawing starts from 3890.
## (b) tracked in r36, walking west: stopped at r36's edge 3 (neighbour 35 is 135 up), stays 36, drawing starts from 36.
## (c) tracked in r36, walking into that edge at 45 degrees (toward +z, inside neighbour 35's span): slides along it.
## (d) saved while tracked in 3890 inside the overlap, then loaded: still tracked in 3890.
## (e) real input: the scene's own physics with the W key held - tracked in 3890 east through the corridor (not refused,
##     never tracked in 36), and tracked in r36 west into wall 8260 (refused, stays east of x 3296.5).
## Phases (a)-(d) drive move_grounded directly (as the earned walks do). Rendered: the mouse must be captured for keys.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
const SAVE := "user://tests/l14_region_tracker/overlap.json"
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL l14 region tracker: ", m)
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
func place(scene: Node, x: float, z: float) -> void:
	scene.player.global_position = Vector3(x, -48, z); scene.player.velocity = Vector3.ZERO
	for i in 10: await physics_frame
	scene.tracker_tick()
## r36 is overlapped along its whole length by the corridor (3890/3894/3901...), so a cold pick takes the corridor:
## track it as arriving through r36's own neighbour would.
func track_r36(scene: Node, x: float, z: float) -> void:
	await place(scene, x, z)
	scene.tracked_region = 36
	scene.tracker_last = scene.player.global_position
	scene.last_collision_region = 36
func walk(scene: Node, direction: Vector3, frames: int) -> void:
	for i in frames:
		scene.move_grounded(direction.normalized(), 1.0 / 60.0)
		await physics_frame
func hold_w(scene: Node, frames: int, stop_x: float = INF) -> void:
	var e := InputEventKey.new(); e.keycode = KEY_W; e.physical_keycode = KEY_W; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events()
	for i in frames:
		await physics_frame
		if scene.player.global_position.x >= stop_x: break
	e = InputEventKey.new(); e.keycode = KEY_W; e.physical_keycode = KEY_W; e.pressed = false
	Input.parse_input_event(e); Input.flush_buffered_events()
	for i in 5: await physics_frame
func start_room(scene: Node) -> int:
	return int(scene.tracked_region_for(scene.player.global_position + Vector3.UP * 42.0))
func run() -> void:
	set_meta("original_game_verified", true)
	# The tracker mechanism at r36/3890 is tested on the original layout: with the geometry moves on, the T14 trench
	# (r36 included) sits above the corridor and the overlap no longer exists (l14_small_zones_test covers that).
	set_meta("lol2_geometry_move_off", true)
	var scene: Node = await open_l14()
	if scene == null: return fail("L14 did not open")
	if not scene.tracker_on: return fail("tracker off on L14")
	scene.set_physics_process(false)
	# (a) tracked in 3890 (west of r36), walking east into the overlap.
	await place(scene, 3262, -3520)
	if scene.tracked_region != 3890: return fail("(a) start not tracked in 3890 (%d)" % scene.tracked_region)
	var refused: int = scene.tracker_refused
	for i in 240:
		if scene.player.global_position.x >= 3312.0: break
		await walk(scene, Vector3(1, 0, 0), 1)
	var pa: Vector3 = scene.player.global_position
	if pa.x < 3312: return fail("(a) walking east from 3890 was stopped at x %.1f" % pa.x)
	if scene.tracker_refused != refused: return fail("(a) a step was refused while tracked in 3890")
	if scene.tracked_region != 3890: return fail("(a) tracked region changed to %d in the overlap" % scene.tracked_region)
	if start_room(scene) != 3890: return fail("(a) portal drawing does not start from 3890 (%d)" % start_room(scene))
	# (d) save here (tracked 3890 inside the overlap), load, still 3890.
	var Save = load("res://scripts/lol2/game_save.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests/l14_region_tracker"))
	var werr: String = Save.write_document(SAVE, Save.make_document(scene, Save.AUTOSAVE))
	if not werr.is_empty(): return fail("(d) save: " + werr)
	var lerr: String = Save.load_file(self, ProjectSettings.globalize_path(SAVE))
	if not lerr.is_empty(): return fail("(d) load: " + lerr)
	var old := scene
	scene = null
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene != old and current_scene.get("player") is Node3D and current_scene.is_node_ready(): scene = current_scene; break
	if scene == null: return fail("(d) reloaded L14 did not open")
	for i in 20: await physics_frame
	scene.set_physics_process(false)
	if scene.tracked_region != 3890: return fail("(d) loaded in the overlap tracked in %d, not 3890" % scene.tracked_region)
	# (b) tracked in r36 (south of 3890's quad), walking west: stopped at r36 edge 3.
	await track_r36(scene, 3316, -3600)
	if scene.tracked_region != 36: return fail("(b) start not tracked in 36 (%d)" % scene.tracked_region)
	refused = scene.tracker_refused
	await walk(scene, Vector3(-1, 0, 0), 60)
	var pb: Vector3 = scene.player.global_position
	if pb.x < 3296.5: return fail("(b) walked through r36 edge 3 to x %.1f" % pb.x)
	if scene.tracker_refused == refused: return fail("(b) no step was refused at r36 edge 3")
	if scene.tracked_region != 36: return fail("(b) tracked region changed to %d" % scene.tracked_region)
	if start_room(scene) != 36: return fail("(b) portal drawing does not start from 36 (%d)" % start_room(scene))
	# (c) 45 degrees into the same edge: slides north along it.
	await track_r36(scene, 3312, -3600)
	var z0: float = scene.player.global_position.z
	for i in 120:
		if scene.player.global_position.z >= -3530.0: break
		await walk(scene, Vector3(-1, 0, 1), 1)
	var pc: Vector3 = scene.player.global_position
	if pc.x < 3296.5: return fail("(c) crossed the edge at x %.1f" % pc.x)
	if pc.z - z0 < 40.0: return fail("(c) no slide along the edge (dz %.1f)" % (pc.z - z0))
	# (e) real input with the scene's physics on (movement keys count only with the mouse captured, as in play).
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(true)
	scene.tracked_region = -1
	await place(scene, 3262, -3520)
	scene.player.rotation.y = -PI / 2.0   # facing +x (east)
	if scene.tracked_region != 3890: return fail("(e) start not tracked in 3890 (%d)" % scene.tracked_region)
	refused = scene.tracker_refused
	var seen36 := false
	var ex0: float = scene.player.global_position.x
	var e_down := InputEventKey.new(); e_down.keycode = KEY_W; e_down.physical_keycode = KEY_W; e_down.pressed = true
	Input.parse_input_event(e_down); Input.flush_buffered_events()
	for i in 240:
		await physics_frame
		if scene.tracked_region == 36: seen36 = true
		if scene.player.global_position.x >= 3312.0: break
	await hold_w(scene, 0)
	var pe: Vector3 = scene.player.global_position
	if pe.x - ex0 < 10.0: return fail("(e) W did not move him (x %.1f -> %.1f)" % [ex0, pe.x])
	if pe.x < 3305.0: return fail("(e) W east from 3890 stopped at x %.1f" % pe.x)
	if seen36 or scene.tracker_refused != refused: return fail("(e) W east from 3890 tracked 36 or refused (refusals %d)" % (scene.tracker_refused - refused))
	await track_r36(scene, 3316, -3600)
	scene.player.rotation.y = PI / 2.0    # facing -x (west)
	refused = scene.tracker_refused
	await hold_w(scene, 90)
	var pf: Vector3 = scene.player.global_position
	if pf.x < 3296.5: return fail("(e) W west from r36 went through wall 8260 to x %.1f" % pf.x)
	if scene.tracker_refused == refused: return fail("(e) W west from r36: no step refused (x %.1f)" % pf.x)
	print("PASS l14 region tracker real input: W east from 3890 to x %.0f, W west from r36 held at x %.1f" % [pe.x, pf.x])
	print("PASS l14 region tracker: 3890 east into the overlap free (x %.0f), r36 west stopped at x %.1f, 45-degree slide %.0f units at x %.1f, overlap save/load kept 3890, drawing from the tracked room" % [pa.x, pb.x, pc.z - z0, pc.x])
	quit(0)
