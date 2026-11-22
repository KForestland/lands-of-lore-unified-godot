extends SceneTree
## Owner r17 16-37-36 at Museum (3001, -813): the plank should go in the hole.
## Walk to that spot with a sword already in hand, look level at the beam, and press E.
const HELD := "museum:item11:Fine_Longsword"
const SLOT_X := 3119.0
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL plank: ", message)
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
	if not is_instance_valid(scene.plank):
		fail("Plank host missing")
		return
	var landed := false
	var walk_error := ""
	for start in [Vector3(3001.0, 50.0, -680.0), Vector3(2850.0, 50.0, -813.0), Vector3(3001.0, 50.0, -900.0)]:
		var body: CharacterBody3D = scene.player
		body.global_position = start
		body.velocity = Vector3.ZERO
		walk_error = await walk_to(Vector2(3001.0, -813.0))
		if walk_error.is_empty():
			landed = true
			break
		body.velocity = Vector3.ZERO
	if not landed:
		fail(walk_error)
		return
	var before: AABB = scene.plank.beam_bounds()
	if before.end.x >= SLOT_X or before.position.y < 34.0 or before.end.y > 44.0:
		fail("Beam was not the placed bar at %s" % before)
		return
	var center: Vector3 = before.get_center()
	var cam: Camera3D = scene.camera
	cam.look_at(Vector3(center.x, cam.global_position.y, center.z), Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not HELD in scene.carried_collected:
		scene.carried_collected.append(HELD)
	scene.hand_item = HELD
	var hint: String = scene.plank.interaction_hint()
	var exhibit: String = scene.skeleton_population.control_hint() if is_instance_valid(scene.skeleton_population) else ""
	if hint != "E — Slide the plank in" and exhibit != "E — Touch the exhibit":
		var fwd: Vector3 = -cam.global_basis.z
		fail("Level look missed the beam at %s from %s fwd %s hint %s exhibit %s" % [before, scene.player.global_position, fwd, hint, exhibit])
		return
	press_e()
	if scene.plank.state != 1 or scene.hand_item != HELD:
		fail("E did not start the slide hand %s state %s" % [scene.hand_item, scene.plank.state])
		return
	if not bool(scene.skeleton_population.state.actors["20"].woken):
		fail("Control 92 did not wake actor 20")
		return
	var door_up := false
	for i in 200:
		await physics_frame
		var box: AABB = scene.plank.beam_bounds()
		if scene.plank.state == 2 and box.end.x > SLOT_X and box.position.y > 34.0 and box.position.y < 44.0 and scene.dragon_door.position.y > 70.0:
			door_up = true
			break
	var done: AABB = scene.plank.beam_bounds()
	if not door_up:
		fail("Beam or door did not finish box %s door y %s state %s" % [done, scene.dragon_door.position.y, scene.plank.state])
		return
	if done.position.x >= SLOT_X:
		fail("The whole beam left the hall %s" % done)
		return
	var stood := Vector2(scene.player.global_position.x, scene.player.global_position.z)
	if stood.distance_to(Vector2(3001.0, -813.0)) > 8.0:
		fail("Did not stay at the owner spot %s" % scene.player.global_position)
		return
	print("PASS plank: walked to (3001,-813), a level look with a held sword slid the beam into the slot, and the door opened")
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
			return "Fell on the way to the plank at %s" % body.global_position
		if body.global_position.distance_to(previous) < 0.05:
			stuck += 1
			if stuck >= 25:
				return "Stuck on the way to the plank at %s" % body.global_position
		else:
			stuck = 0
			previous = body.global_position
	var left: float = (target - Vector2(body.global_position.x, body.global_position.z)).length()
	return "Stopped %.1f short of the plank at %s" % [left, body.global_position]

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

func press_e() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	scene._unhandled_input(event)
