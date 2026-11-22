extends SceneTree
## Owner r17 16-40-18 at Jungle (-698, -4230): two Huline women should be here, talking about the missing cats.
## Control 186 plays E056E.VQA. Loiter (segment 1) is up when you arrive. E starts segment 0, the first talk.
const Form := preload("res://scripts/lol2/player_form_body.gd")
const OWNER := Vector2(-698.0, -4230.0)
const START := Vector2(-900.0, -4350.0)
const APPROACH := Vector2(-698.0, -4350.0)
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL cat ladies: ", message)
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
	if scene.cat_ladies == null or not is_instance_valid(scene.cat_ladies):
		fail("Cat ladies missing")
		return
	var walk_error: String = await walk_to(START, APPROACH)
	if not walk_error.is_empty():
		fail(walk_error)
		return
	walk_error = await walk_to(APPROACH, OWNER)
	if not walk_error.is_empty():
		fail(walk_error)
		return
	var ladies = scene.cat_ladies
	if not ladies.mesh.visible or int(ladies.segment) != 1:
		fail("The women were not loitering at %s (segment %s)" % [scene.player.global_position, ladies.segment])
		return
	aim(ladies.anchor() + Vector3.UP * 40.0)
	await physics_frame
	if not ladies.aimed():
		fail("Looking at the women did not meet them, at %s" % scene.player.global_position)
		return
	press_e(ladies)
	await physics_frame
	if int(ladies.segment) != 0 or int(ladies.owner_state) != 2:
		fail("E did not start the first talk (segment %s state %s)" % [ladies.segment, ladies.owner_state])
		return
	if not ladies.voice.playing:
		fail("The first talk made no sound")
		return
	print("PASS cat ladies: walked to (-698,-4230), the two women were loitering, and E started their first talk")
	quit(0)

func walk_to(start: Vector2, target: Vector2) -> String:
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
	return "Stopped %.1f short of %s at %s" % [left, target, body.global_position]

func plant(at: Vector2) -> void:
	var body: CharacterBody3D = scene.player
	var top := Vector3(at.x, 80.0, at.y)
	var query := PhysicsRayQueryParameters3D.create(top, top - Vector3.UP * 400.0, 1, [body.get_rid()])
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	var ground := 0.0
	if not hit.is_empty():
		ground = hit.position.y
	body.global_position = Vector3(at.x, ground + Form.FOOT_OFFSET, at.y)
	body.velocity = Vector3.ZERO

func aim(at: Vector3) -> void:
	scene.camera.look_at(at, Vector3.UP)

func press_e(ladies) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	event.echo = false
	ladies._unhandled_input(event)
