extends SceneTree
## Hive lift call post (owner 2026-10-23 20:36:13 "button do not work"): at the owner's pose by post 127 with the lift
## already at stop 1, a real E press clicks (native op20 sound 388 at the post, groups 8256/8278) and keeps stop 1.
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL hive_elevator_post_click: ", message); quit(1)
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	for i in 600:
		await process_frame
		if scene.get("ready_for_review"): break
	var lift = scene.elevator
	if lift == null: return fail("No elevator")
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	lift.checkpoint.target = 1
	var offset: Vector3 = scene.camera.global_position - scene.player.global_position
	scene.player.global_position = Vector3(-2353.76416015625, -384.958312988281, -7835.78857421875) - offset
	var direction: Vector3 = lift.aim_point(127) - scene.camera.global_position
	scene.player.rotation = Vector3(0, atan2(-direction.x, -direction.z), 0)
	scene.camera.rotation = Vector3(atan2(direction.y, Vector2(direction.x, direction.z).length()), 0, 0)
	for i in 3: await physics_frame
	if lift.target_control() != 127: return fail("Post127 not targeted from the owner's spot (got %d)" % lift.target_control())
	var e := InputEventKey.new(); e.keycode = KEY_E; e.physical_keycode = KEY_E; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events()
	for i in 3: await process_frame
	if lift.clicks != 1 or not lift.click.playing or int(lift.checkpoint.target) != 1: return fail("E did not click (clicks %d, target %s)" % [lift.clicks, lift.checkpoint.target])
	print("PASS hive_elevator_post_click: E at post127 from the owner's spot plays the original button click (388); stop stays 1")
	quit(0)
