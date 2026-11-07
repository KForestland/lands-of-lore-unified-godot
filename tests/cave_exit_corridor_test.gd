extends SceneTree
## Cave exit to the Museum at native region1221 (the corridor before the chamber; event2 on entry runs g1454): holding W
## and jumping from region892 into the corridor starts the chamber arrival inside 1221, so a jump cannot carry the
## player past it (owner 2026-10-23 19:59:35 "you can jump over the exit to museum").
var scene
var held := []
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	release(); push_error(message); print("FAIL cave_exit_corridor: ", message); quit(1)
func key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new(); e.physical_keycode = code; e.keycode = code; e.pressed = pressed; Input.parse_input_event(e)
	if pressed: held.append(code)
	else: held.erase(code)
func release() -> void:
	for code in held.duplicate(): key(code, false)
func run() -> void:
	scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in range(900):
		await process_frame
		if scene.walkthrough_ready: break
	if not scene.walkthrough_ready: return fail("Cave not ready")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if scene.chamber_arrival_state != "not_started": return fail("Arrival already started")
	var t: Vector3 = scene.native_translation
	scene.player.global_position = t + Vector3(-63, -295 + 34, -18115); scene.player.velocity = Vector3.ZERO
	scene.player.rotation = Vector3.ZERO; scene.camera.rotation = Vector3.ZERO
	for i in 20: await physics_frame
	if scene.chamber_arrival_state != "not_started": return fail("Arrival started in region892")
	key(KEY_SHIFT, true); key(KEY_W, true)
	var started_at := Vector3.INF
	for i in 600:
		if i % 30 == 5: key(KEY_SPACE, true)
		if i % 30 == 9: key(KEY_SPACE, false)
		await physics_frame
		if scene.chamber_arrival_state != "not_started": started_at = scene.player.global_position - t; break
	release()
	if started_at == Vector3.INF: return fail("Walking and jumping through the corridor did not start the arrival (at %s)" % (scene.player.global_position - t))
	if started_at.z > -18137.0 or started_at.z < -18435.0: return fail("Arrival started outside region1221: %s" % started_at)
	print("PASS cave_exit_corridor: sprint + jumps from region892 start the chamber arrival inside region1221 at %s" % started_at)
	quit(0)
