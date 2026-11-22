extends SceneTree
## Owner r17 16-49-32 at Hive (-1179, -8839): the conversation woman was a 3-metre cat.
## Walk the source room-to-conversation points and speak. She should stand about as tall as Luther.
const Form := preload("res://scripts/lol2/player_form_body.gd")
const POINTS: Array[Vector2] = [
	Vector2(-1218, -8725),
	Vector2(-1225.5, -8737),
	Vector2(-1230, -8762),
	Vector2(-1228, -8784),
	Vector2(-1215.5, -8808),
	Vector2(-1191.5, -8836.5),
	Vector2(-1174, -8843),
]
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL hive cat: ", message)
	quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 30:
		await process_frame
		if scene.get("ready_for_review"):
			break
	if not scene.get("ready_for_review"):
		fail("Hive not ready")
		return
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var actor = scene.get_node("ConversationReview")
	var quad: QuadMesh = actor.mesh as QuadMesh
	if quad == null:
		fail("Conversation has no quad")
		return
	var authored_height := float(actor.data.size[1])
	var authored_width := float(actor.data.size[0])
	if not is_equal_approx(authored_height, 128.0) or not is_equal_approx(authored_width, 142.5):
		fail("The pack size changed to %s" % [quad.size])
		return
	if not is_equal_approx(quad.size.y, 44.0) or quad.size.y > Form.HEIGHTS[0]:
		fail("She is still %.1f units tall" % quad.size.y)
		return
	if not is_equal_approx(quad.size.x / quad.size.y, authored_width / authored_height):
		fail("The scale changed her proportions")
		return
	var feet: float = actor.global_position.y + quad.center_offset.y - quad.size.y * 0.5
	if not is_equal_approx(feet, actor.global_position.y):
		fail("Her feet left the floor at %.1f" % feet)
		return
	if actor.prompt.position.y < quad.size.y or actor.prompt.position.y > quad.size.y + 20.0:
		fail("The speak prompt is not above her head")
		return
	for index in POINTS.size():
		var point: Vector2 = POINTS[index]
		var blocked: String = await walk_to(point)
		if not blocked.is_empty():
			fail(blocked)
			return
		if index == 0:
			for _tick in 8:
				await process_frame
			if not actor.room_entered:
				fail("Walking into the rune room did not admit her")
				return
	scene.camera.look_at(actor.aim_point(), Vector3.UP)
	for _tick in 5:
		await process_frame
	if not actor.can_begin() or not actor.prompt.visible:
		fail("She did not offer to speak at %s" % scene.player.global_position)
		return
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	event.echo = false
	actor._unhandled_input(event)
	if not actor.started or actor.frame != 0:
		fail("E did not start her line (frame %d)" % actor.frame)
		return
	print("PASS hive cat: walked from the rune room to the woman at (-1174,-8843), and she stands about the player's height")
	quit(0)

func walk_to(target: Vector2) -> String:
	var body: CharacterBody3D = scene.player
	if body.global_position.distance_to(Vector3(target.x, body.global_position.y, target.y)) > 80.0:
		plant(target)
		for i in 15:
			await physics_frame
			scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
	var floor_y: float = body.global_position.y
	var stuck := 0
	var previous := body.global_position
	for i in 700:
		var flat := target - Vector2(body.global_position.x, body.global_position.z)
		if flat.length() < 8.0:
			return ""
		await physics_frame
		scene.move_grounded(Vector3(flat.x, 0.0, flat.y).normalized(), 1.0 / 60.0)
		if body.global_position.y < floor_y - 48.0:
			return "Fell on the way to %s at %s" % [target, body.global_position]
		if body.global_position.distance_to(previous) < 0.05:
			stuck += 1
			if stuck >= 25:
				return "Stuck on the way to %s at %s" % [target, body.global_position]
		else:
			stuck = 0
			previous = body.global_position
	return "Stopped short of %s at %s" % [target, body.global_position]

func plant(at: Vector2) -> void:
	var body: CharacterBody3D = scene.player
	var top := Vector3(at.x, -150.0, at.y)
	var query := PhysicsRayQueryParameters3D.create(top, Vector3(at.x, -420.0, at.y), 1, [body.get_rid()])
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	var ground := -235.0
	if not hit.is_empty():
		ground = float(hit.position.y)
	body.global_position = Vector3(at.x, ground + Form.FOOT_OFFSET, at.y)
	body.velocity = Vector3.ZERO
