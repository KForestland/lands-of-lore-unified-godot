extends SceneTree
## Shining Path by walking in (native region1419 entry event → g1724/g7218/g7306): holding W from the corridor toward
## the mirror crosses the region1419 strip and travels to the Jungle, as the owner expected on 2026-10-23 (report
## 20:01:52, E in front of the mirror did nothing). A player placed inside the strip (a load) does not travel until
## stepping in again; E at the strip still works (museum_mirror_route_test).
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	Input.parse_input_event(_key(false)); push_error(message); print("FAIL museum_mirror_walk_in: ", message); quit(1)
func _key(pressed: bool) -> InputEventKey:
	var e := InputEventKey.new(); e.physical_keycode = KEY_W; e.keycode = KEY_W; e.pressed = pressed; return e
func run() -> void:
	scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene); current_scene = scene
	for i in 30: await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Placed inside the strip (as a load would): no travel while standing there.
	# Placed inside the strip from the corridor (a load or a test placement is not a step in).
	scene.player.global_position = Vector3(-4058, 20, -1345)
	for i in 5: await physics_frame
	scene.player.global_position = Vector3(-4058, 20, -1381); scene.player.velocity = Vector3.ZERO
	scene.player.rotation = Vector3.ZERO; scene.camera.rotation = Vector3.ZERO
	for i in 40: await physics_frame
	if scene.mirror_transition_pending: return fail("Standing inside the strip after a load travelled")
	# Back out into the corridor, then walk in holding W.
	scene.player.global_position = Vector3(-4058, 20, -1345); scene.player.velocity = Vector3.ZERO
	for i in 20: await physics_frame
	if scene.mirror_transition_pending or scene.mirror_was_inside: return fail("Corridor start is inside the strip")
	Input.parse_input_event(_key(true))
	for i in 240:
		await physics_frame
		if not is_instance_valid(scene) or scene.mirror_transition_pending: break
	Input.parse_input_event(_key(false))
	if is_instance_valid(scene) and not scene.mirror_transition_pending: return fail("Walking into region1419 did not travel (player %s)" % scene.player.global_position)
	for i in 30:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with("jungle_walkthrough.tscn"): break
	if current_scene == null or not current_scene.scene_file_path.ends_with("jungle_walkthrough.tscn"): return fail("The Jungle did not load")
	print("PASS museum_mirror_walk_in: W into region1419 travels to the Jungle; a placement inside the strip waits for a fresh step in")
	quit(0)
