extends SceneTree
## L14 small-zone moves (lead 2026-11-13; tools/prepare_geometry_move.py zone table, scripts/lol2/geometry_moves/L14_HT.json).
## T14 (r36/3890): the trench 34/36/38/40 behind the hall wall had its floor at -80 inside the lower corridor's band
## (3874..3906, floor -80, ceiling 20); its floor now stands at 25 (ceiling 90 kept), wholly above the corridor.
## Its only openings, the four 20-high window sills 33/35/37/39, are solid for the player (a lizard fits through and
## the trench has no way out - an original no-exit trap). Real input (W held, mouse captured):
##  (a) tracked in 3890, W east through the trench's old footprint at corridor height: never refused, never tracked in
##      36, reaches x 3312 (the r36 wall no longer crosses the corridor);
##  (b) as the lizard (form 2, set as a test aid) on sill 35 facing the trench, W held: stopped at the opening.
## Also: the moved set is loaded and the trench floor in the tracker table is 25.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
const FormBody = preload("res://scripts/lol2/player_form_body.gd")
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL l14 small zones: ", m)
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
func run() -> void:
	set_meta("original_game_verified", true)
	var scene: Node = await open_l14()
	if scene == null: return fail("L14 did not open")
	if not str(scene.geometry_file).ends_with("area_moved.json"): return fail("moved pack not loaded")
	var trench_floor: float = scene._tracker_floor(36, Vector3(3311, 0, -3560))
	if absf(trench_floor - 25.0) > 0.5: return fail("trench floor in the tracker table is %.1f, not 25" % trench_floor)
	for r in [34, 36, 38, 40]:
		if scene.tracker_overlaps.has(r): return fail("trench region %d still listed as an overlap" % r)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.set_physics_process(true)
	# (a) corridor under the trench
	scene.tracked_region = -1
	scene.player.global_position = Vector3(3262, -46, -3520); scene.player.velocity = Vector3.ZERO
	scene.player.rotation.y = -PI / 2.0
	for i in 15: await physics_frame
	if scene.tracked_region != 3890: return fail("(a) start not tracked in 3890 (%d)" % scene.tracked_region)
	var refused: int = scene.tracker_refused
	var seen36 := false
	key(KEY_W, true)
	for i in 240:
		await physics_frame
		if scene.tracked_region == 36: seen36 = true
		if scene.player.global_position.x >= 3312.0: break
	key(KEY_W, false)
	for i in 5: await physics_frame
	var pa: Vector3 = scene.player.global_position
	if pa.x < 3312.0: return fail("(a) W east through the corridor stopped at x %.1f" % pa.x)
	if seen36 or scene.tracker_refused != refused: return fail("(a) tracked in 36 or refused under the trench")
	# (b) lizard at the sill 35 -> 36 opening
	scene.set("player_form", 2)
	FormBody.apply(scene.player, scene.camera, 2, false)
	scene.tracked_region = -1
	scene.player.global_position = Vector3(3282, 55 + 32 + 2, -3560); scene.player.velocity = Vector3.ZERO
	scene.player.rotation.y = -PI / 2.0   # facing +x, into the trench
	for i in 20: await physics_frame
	var x0: float = scene.player.global_position.x
	key(KEY_W, true)
	for i in 120: await physics_frame
	key(KEY_W, false)
	for i in 5: await physics_frame
	var pb: Vector3 = scene.player.global_position
	if pb.x - x0 < 5.0: return fail("(b) the lizard did not move on the sill (x %.1f -> %.1f)" % [x0, pb.x])
	if pb.x > 3298.5: return fail("(b) the lizard went through the sill opening to x %.1f (feet %.1f)" % [pb.x, pb.y - 32.0])
	print("PASS l14 small zones: T14 trench floor 25, no trench overlap; W east under it from 3890 to x %.0f unrefused; lizard on sill 35 stopped at x %.1f" % [pa.x, pb.x])
	quit(0)
