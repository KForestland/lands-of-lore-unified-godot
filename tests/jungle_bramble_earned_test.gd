extends SceneTree
## OF2. Owner F10 at Jungle (-3632, 2229), control 103: three cuts open the roots,
## and the regrown wall is selector 0 (the full roots) with the box back.
## The same host used to stop on selector 5, the open frame, while the box stayed.
const Form := preload("res://scripts/lol2/player_form_body.gd")
const WALL := 103
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL bramble: ", message)
	quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"):
			break
	if not scene.get("ready_for_review"):
		fail("Jungle not ready")
		return
	scene.set_physics_process(false)
	if is_instance_valid(scene.village_alarm):
		scene.village_alarm.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if scene.bramble == null or not is_instance_valid(scene.bramble):
		fail("Bramble missing")
		return
	var bramble = scene.bramble
	var solid: StaticBody3D = scene.static_assemblies.solid_bodies[WALL]
	var centre := Vector2(solid.global_position.x, solid.global_position.z)
	var report := Vector2(-3632.0, 2229.0)
	var away: Vector2 = report - centre
	if away.length() < 1.0:
		var normal: Vector3 = solid.global_transform.basis.z
		away = Vector2(normal.x, normal.z)
	away = away.normalized()
	var near: Vector2 = centre + away * 55.0
	var far: Vector2 = centre - away * 55.0
	var blocked: String = await walk_to(near, far, true)
	if blocked.is_empty():
		fail("Walked through the bramble at %s" % scene.player.global_position)
		return
	if not blocked.begins_with("Stuck"):
		fail(blocked)
		return
	if not bramble.solid(WALL):
		fail("The wall was already open")
		return
	scene.equipped_item = scene.SWORD_ITEM_ID
	aim(solid.global_position)
	await physics_frame
	var steps: Array[int] = [1, 2, 3]
	for step in steps:
		press_click(bramble)
		await physics_frame
		if bramble.owner_state(WALL) != step:
			fail("Cut %d left the wall at state %d" % [step, bramble.owner_state(WALL)])
			return
	if bramble.solid(WALL) or bramble.selector(WALL) != 3:
		fail("The third cut did not open the wall")
		return
	var crossed: String = await walk_to(Vector2(scene.player.global_position.x, scene.player.global_position.z), far, false)
	if not crossed.is_empty():
		fail(crossed)
		return
	var grew := false
	for i in 800:
		await physics_frame
		var shown: int = int(scene.static_assemblies.modes.get(WALL, -1))
		if bramble.solid(WALL) and bramble.owner_state(WALL) == 0 and bramble.selector(WALL) == 0 and shown == 0:
			grew = true
			break
	if not grew:
		fail("The cut wall did not grow back (state %d)" % bramble.owner_state(WALL))
		return
	var closed: String = await walk_to(far, near, true)
	if closed.is_empty():
		fail("Walked through the regrown bramble at %s" % scene.player.global_position)
		return
	if not closed.begins_with("Stuck"):
		fail(closed)
		return
	aim(solid.global_position)
	await physics_frame
	press_q()
	await physics_frame
	if bramble.solid(WALL) or bramble.owner_state(WALL) != 5 or bramble.selector(WALL) != 4:
		fail("Spark left the wall solid=%s state=%d selector=%d" % [bramble.solid(WALL), bramble.owner_state(WALL), bramble.selector(WALL)])
		return
	var burned: String = await walk_to(Vector2(scene.player.global_position.x, scene.player.global_position.z), near, false)
	if not burned.is_empty():
		fail(burned)
		return
	print("PASS bramble: control 103 at the reported stand opens on the third cut, grows back as the full roots, and Spark burns it down")
	quit(0)

func walk_to(start: Vector2, target: Vector2, expect_block: bool) -> String:
	plant(start)
	for i in 20:
		await physics_frame
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
	var body: CharacterBody3D = scene.player
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
	var left: float = (target - Vector2(body.global_position.x, body.global_position.z)).length()
	if expect_block:
		return "Stopped %.1f short of %s at %s" % [left, target, body.global_position]
	return "Stopped %.1f short of %s at %s" % [left, target, body.global_position]

func plant(at: Vector2) -> void:
	var body: CharacterBody3D = scene.player
	var top := Vector3(at.x, -20.0, at.y)
	var query := PhysicsRayQueryParameters3D.create(top, top - Vector3.UP * 160.0, 1, [body.get_rid()])
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	var ground := -70.0
	if not hit.is_empty():
		ground = hit.position.y
	body.global_position = Vector3(at.x, ground + Form.FOOT_OFFSET, at.y)
	body.velocity = Vector3.ZERO

func aim(at: Vector3) -> void:
	scene.camera.look_at(at, Vector3.UP)

func press_click(bramble) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	bramble._unhandled_input(event)

func press_q() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_Q
	event.pressed = true
	event.echo = false
	scene.starting_magic._unhandled_input(event)
