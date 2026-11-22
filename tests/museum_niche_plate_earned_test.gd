extends SceneTree
## Owner r17 16-33-54 at (-1936,-1109): the niche hall looked like a softlock because
## the wall plate did not read as a switch. Walk there, look level at the plate with
## another item in the hand, press E, then walk back.
const Torches = preload("res://scripts/lol2/museum_torches.gd")
const HELD := "museum:item11:Fine_Longsword"
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL niche plate: ", message)
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
	if not await walk_to(Vector2(-1936.0, -1109.0), Vector3(-1936.0, 80.0, -1080.0)):
		return
	var stood: Vector3 = body.global_position
	if not await walk_to(Vector2(-1882.5, -1060.0), body.global_position):
		return
	var aim_row: Array = scene.museum_torches.source.switch.aim
	var aim := Vector3(float(aim_row[0]), float(aim_row[1]), float(aim_row[2]))
	level_look(aim)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not HELD in scene.carried_collected:
		scene.carried_collected.append(HELD)
	scene.hand_item = HELD
	var mat := scene.museum_torches.plate.material_override as StandardMaterial3D
	if mat == null or mat.albedo_color != Torches.PLATE_TINT:
		fail("The plate is not tinted apart from the wall")
		return
	if scene.museum_torches.interaction_hint() != "E — Press the wall plate":
		var cam: Camera3D = scene.camera
		var fwd: Vector3 = -cam.global_basis.z
		var delta: Vector3 = aim - cam.global_position
		fail("Level look gives no plate hint at %s cam %s dot %.3f" % [body.global_position, cam.global_position, fwd.dot(delta.normalized())])
		return
	press_e()
	if scene.hand_item != "" or not (HELD in scene.carried_collected):
		fail("E did not put the longsword away (hand %s)" % scene.hand_item)
		return
	if int(scene.museum_torches.state.pilot_state) != 1 or not is_equal_approx(scene.museum_torches.plate.position.y, Torches.PLATE_LIFT):
		fail("E did not open the plate")
		return
	if not await walk_to(Vector2(stood.x, stood.z), body.global_position):
		return
	print("PASS niche plate: walked from (-1936,-1109) to the wall plate, a held longsword was put away, the panel opened, and the walk back stayed in the hall")
	quit(0)

func walk_to(target: Vector2, from: Vector3) -> bool:
	var body: CharacterBody3D = scene.player
	body.global_position = from
	body.velocity = Vector3.ZERO
	var stuck := 0
	var previous := body.global_position
	for i in 500:
		var flat := target - Vector2(body.global_position.x, body.global_position.z)
		if flat.length() < 6.0:
			return true
		await physics_frame
		step(Vector3(flat.x, 0.0, flat.y).normalized())
		if body.global_position.y < -40.0:
			fail("Fell on the way to %s at %s" % [target, body.global_position])
			return false
		if body.global_position.distance_to(previous) < 0.05:
			stuck += 1
			if stuck >= 25:
				fail("Stuck on the way to %s at %s" % [target, body.global_position])
				return false
		else:
			stuck = 0
			previous = body.global_position
	var left: float = (target - Vector2(body.global_position.x, body.global_position.z)).length()
	fail("Stopped %.1f short of %s at %s" % [left, target, body.global_position])
	return false

func level_look(aim: Vector3) -> void:
	var body: CharacterBody3D = scene.player
	var flat := Vector3(aim.x, body.global_position.y, aim.z)
	body.look_at(flat, Vector3.UP)
	scene.camera.rotation = Vector3.ZERO

func press_e() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	scene._unhandled_input(event)

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
