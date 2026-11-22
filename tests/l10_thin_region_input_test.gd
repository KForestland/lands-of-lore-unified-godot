extends SceneTree
## Thin hanging regions solid to the player (owner F10 2026-11-15 03-27-37, L10 yard; scripts/lol2/thin_region_blocks.gd).
## Region 1029 (floor 35, ceiling 45) hangs over the yard (floor 0); walking east along the wall beside it slid the body
## under its floor face and wedged it: feet 7 into the yard floor, every direction blocked, no input frees it.
##  (a) real W from the owner's last free pose (-57.95, -3811.67) heading -1.80: the body is turned aside at the strip's
##      edge, stays on the yard floor, and real S walks it away again.
##  (b) a body already inside (the owner's trapped pose -42.64, 25.11, -3814.98, as in his save): it is lifted out onto the
##      yard floor, and real S and A move it.
## Red (r19n 7ca0961): (a) ends at h 25.11 with no free direction; (b) stays at h 25.11 through W/A/S/D/Space.
## Test aids: the F2 start of the level and the two placed poses.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
var scene: Node
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL thin region input: ", m)
	quit(1)
func hold(code: Key, frames: int) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events()
	for i in frames: await physics_frame
	e.pressed = false; Input.parse_input_event(e); Input.flush_buffered_events()
	for i in 10: await physics_frame
func place(at: Vector3, yaw: float) -> void:
	scene.player.global_position = at; scene.player.rotation.y = yaw; scene.player.velocity = Vector3.ZERO
	for i in 10: await physics_frame
func run() -> void:
	if DisplayServer.get_name() == "headless": return fail("rendered run required")
	var entry := {}
	for c in Starts.manifest().entries:
		if str(c.id) == "act2-l10": entry = c
	var old := current_scene
	var err: String = load("res://scripts/lol2/game_save.gd").resume_checkpoint(self, entry.area_id, Starts.read(entry).state, true)
	if not err.is_empty(): return fail(err)
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene != old and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	scene = current_scene
	for i in 60: await physics_frame
	if not is_instance_valid(scene.get("thin_region_blocks")): return fail("no ThinRegionBlocks on L10")
	# (a) walking in
	await place(Vector3(-57.95, 32.04, -3811.67), -1.80)
	await hold(KEY_W, 90)
	var p: Vector3 = scene.player.global_position
	print("THIN (a) after W ", p)
	if p.y < 31.0: return fail("walk east along the wall sank the body to h %.2f" % p.y)
	await hold(KEY_S, 60)
	if scene.player.global_position.distance_to(p) < 20.0: return fail("real S did not walk away from the strip")
	# (b) already inside
	await place(Vector3(-42.64, 25.11, -3814.98), -1.74)
	for i in 10: await physics_frame
	p = scene.player.global_position
	print("THIN (b) lifted to ", p, " lifted ", scene.thin_region_blocks.lifted)
	# Out by either path: the prism's own depenetration or the node's lift; the body must stand on the yard outside 1029.
	var outline := PackedVector2Array([Vector2(-16, -3786), Vector2(-39, -3781), Vector2(-59, -3924), Vector2(-36, -3928)])
	if p.y < 31.0 or Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), outline): return fail("a body inside the strip was not put out onto the yard (h %.2f)" % p.y)
	await hold(KEY_S, 60); await hold(KEY_A, 60)
	if scene.player.global_position.distance_to(p) < 20.0: return fail("real S/A did not move the lifted body")
	if scene.resets != 0: return fail("fall recovery ran")
	print("PASS thin region: real W along the L10 yard wall turned aside at h ", snappedf(p.y, 0.01), "; a body inside region 1029 lifted onto the yard and walks with real S/A; F2 start and placed poses")
	quit(0)
