extends SceneTree
## Owner r17 16-30-49 at (985,-2515): the broken Thohan sword in the case would not
## come away. Walk to that spot, look level at the case, and press E. Then do it
## again while another item is in the hand.
const Broken = preload("res://scripts/lol2/museum_broken_thohan.gd")
const HELD := "museum:item11:Fine_Longsword"
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL broken thohan: ", message)
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
	body.global_position = Vector3(985.0, 80.0, -2420.0)
	body.velocity = Vector3.ZERO
	var target := Vector2(985.0, -2515.0)
	var stuck := 0
	var previous := body.global_position
	for i in 400:
		var flat := target - Vector2(body.global_position.x, body.global_position.z)
		if flat.length() < 6.0:
			break
		await physics_frame
		step(Vector3(flat.x, 0.0, flat.y).normalized())
		if body.global_position.y < -40.0:
			fail("Fell on the way to the case at %s" % body.global_position)
			return
		if body.global_position.distance_to(previous) < 0.05:
			stuck += 1
			if stuck >= 25:
				fail("Stuck on the way to the case at %s" % body.global_position)
				return
		else:
			stuck = 0
			previous = body.global_position
	var left: float = (target - Vector2(body.global_position.x, body.global_position.z)).length()
	if left >= 6.0:
		fail("Stopped %.1f short of the case at %s" % [left, body.global_position])
		return
	level_look()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if scene.broken_thohan.interaction_hint() != "E — Take Broken Thohan":
		var cam: Camera3D = scene.camera
		var aim: Vector3 = scene.broken_thohan.aim_point()
		var fwd: Vector3 = -cam.global_basis.z
		var delta: Vector3 = aim - cam.global_position
		fail("Level look gives no take hint body %s cam %s fwd %s aim %s dot %.3f mouse %s vis %s mesh %s" % [body.global_position, cam.global_position, fwd, aim, fwd.dot(delta.normalized()), Input.mouse_mode, scene.broken_thohan.sword.visible, scene.broken_thohan.sword.mesh.get_class()])
		return
	press_e()
	if not (Broken.ITEM in scene.carried_collected) or scene.hand_item != Broken.ITEM or scene.broken_thohan.sword.visible:
		fail("E did not take the sword")
		return
	# Put it back with the centre aim, then take it while the fine longsword is in hand.
	var aim: Vector3 = scene.broken_thohan.aim_point()
	scene.camera.look_at(aim)
	if scene.broken_thohan.interaction_hint() != "E — Return Broken Thohan":
		fail("Could not aim the return")
		return
	press_e()
	if Broken.ITEM in scene.carried_collected or not scene.broken_thohan.sword.visible:
		fail("E did not return the sword")
		return
	if not HELD in scene.carried_collected:
		scene.carried_collected.append(HELD)
	scene.hand_item = HELD
	level_look()
	if scene.broken_thohan.interaction_hint() != "E — Take Broken Thohan":
		fail("A held longsword hides the take hint")
		return
	press_e()
	if scene.hand_item != Broken.ITEM or not (Broken.ITEM in scene.carried_collected) or not (HELD in scene.carried_collected):
		fail("E with the longsword in hand did not take the broken sword (hand %s)" % scene.hand_item)
		return
	print("PASS broken thohan: walked to (985,-2515), a level look took the sword, and a held longsword was put away")
	quit(0)

func level_look() -> void:
	var body: CharacterBody3D = scene.player
	var aim: Vector3 = scene.broken_thohan.aim_point()
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
