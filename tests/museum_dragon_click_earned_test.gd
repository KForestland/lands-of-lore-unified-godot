extends SceneTree
## Owner r17 16-37-59 at Museum (3049, -1114): the dragon has a point to click.
## Walk through the chamber mouth, look into the alcove, and click.
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL dragon click: ", message)
	quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"):
			break
	if not scene.get("ready_for_review"):
		fail("Museum not ready")
		return
	scene.set_physics_process(false)
	if is_instance_valid(scene.sword_transfer):
		scene.sword_transfer.set_process(false)
	var body: CharacterBody3D = scene.player
	body.global_position = Vector3(3048.0, 50.0, -980.0)
	body.velocity = Vector3.ZERO
	var walk_error := await walk_to(Vector2(3048.0, -1114.0))
	if not walk_error.is_empty():
		fail(walk_error)
		return
	body.rotation.y = 0.0
	scene.camera.rotation.x = -0.19
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.player.velocity = Vector3.ZERO
	scene.set_physics_process(true)
	await physics_frame
	await physics_frame
	scene.set_physics_process(false)
	# r18 merge: the r16 picture hotspot may also cover this look ("Click the dragon — ..."); either click path starts the journey.
	if not scene.interaction_label.text in ["Click — Travel with the dragon", "Click the dragon — Travel with the dragon"]:
		fail("No dragon click hint at %s text %s" % [body.global_position, scene.interaction_label.text])
		return
	click()
	if not scene.mirror_transition_pending or not is_instance_valid(scene.dragon_flight):
		fail("Click did not start the dragon journey label %s" % scene.interaction_label.text)
		return
	print("PASS dragon click: walked to (3049,-1114), looked into the alcove, and a click started the journey")
	quit(0)

func walk_to(target: Vector2) -> String:
	var body: CharacterBody3D = scene.player
	var stuck := 0
	var previous := body.global_position
	for i in 500:
		var flat := target - Vector2(body.global_position.x, body.global_position.z)
		if flat.length() < 6.0:
			return ""
		await physics_frame
		step(Vector3(flat.x, 0.0, flat.y).normalized())
		if body.global_position.y < -40.0:
			return "Fell on the way to the dragon at %s" % body.global_position
		if body.global_position.distance_to(previous) < 0.05:
			stuck += 1
			if stuck >= 25:
				return "Stuck on the way to the dragon at %s" % body.global_position
		else:
			stuck = 0
			previous = body.global_position
	var left: float = (target - Vector2(body.global_position.x, body.global_position.z)).length()
	return "Stopped %.1f short of the dragon at %s" % [left, body.global_position]

func step(dir: Vector3) -> void:
	var body: CharacterBody3D = scene.player
	var planar: Vector2 = scene.walk_feel.velocity(Vector2(dir.x, dir.z) * 80.0, 1.0 / 60.0)
	body.velocity.x = planar.x
	body.velocity.z = planar.y
	body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 320.0 * (1.0 / 60.0)
	var motion := Vector3(body.velocity.x, 0.0, body.velocity.z) * (1.0 / 60.0)
	if body.velocity.y <= 0.0 and preload("res://scripts/lol2/walk_step.gd").try_step(body, motion):
		body.velocity.x = 0.0
		body.velocity.z = 0.0
	body.move_and_slide()

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	scene._unhandled_input(event)
