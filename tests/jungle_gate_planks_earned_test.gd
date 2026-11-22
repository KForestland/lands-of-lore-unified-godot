extends SceneTree
## Owner r17 16-39-14 at Jungle (-1176, -5247): two planks lie in front of the still-standing village doors.
## Those are fallen leaves 80 and 81 (template 74, placement flags 0x1082, bit 0x1000). They stay hidden
## until the existing Force gate consumer breaks both doors. The native 0x0800 producer stays unread.
const Form := preload("res://scripts/lol2/player_form_body.gd")
const OWNER := Vector2(-1176.0, -5247.0)
const SOUTH := Vector2(-1288.0, -5289.0)
const NORTH := Vector2(-1290.0, -5209.0)
const LEAF78 := Vector3(-1378.0, 80.0, -5289.0)
const LEAF79 := Vector3(-1377.0, 80.0, -5209.0)
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL gate planks: ", message)
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
	if scene.static_assemblies == null or not is_instance_valid(scene.static_assemblies):
		fail("Jungle static assemblies missing")
		return
	if scene.gate_leaves == null or not is_instance_valid(scene.gate_leaves):
		fail("Gate leaves missing")
		return
	var walk_error: String = await walk_to(Vector2(-1080.0, -5247.0), OWNER)
	if not walk_error.is_empty():
		fail(walk_error)
		return
	if not doors_up() or planks_down():
		fail("Planks already down at the standing doors, at %s" % scene.player.global_position)
		return
	walk_error = await walk_to(OWNER, SOUTH)
	if not walk_error.is_empty():
		fail(walk_error)
		return
	aim(LEAF78)
	await physics_frame
	if scene.gate_leaves.interaction_hint() != "The village gate is closed.":
		fail("Closed gate did not refuse the force: '%s'" % scene.gate_leaves.interaction_hint())
		return
	press_e()
	await physics_frame
	if not doors_up() or planks_down():
		fail("A refused force laid the planks")
		return
	scene.raise_huline_alert()
	if scene.confidante == null or scene.confidante.state.is_empty():
		fail("Confidante state missing")
		return
	scene.confidante.state.locals["39"] = 1
	if planks_down():
		fail("The story alone laid the planks")
		return
	aim(LEAF78)
	await physics_frame
	if not scene.gate_leaves.interaction_hint().begins_with("E — Force gate"):
		fail("South door did not offer the force: '%s'" % scene.gate_leaves.interaction_hint())
		return
	press_e()
	await physics_frame
	if not scene.village_gate.leaf_removed(78) or not scene.gate_leaves.panels["81"].visible:
		fail("Forcing the south door did not lay plank 81")
		return
	if scene.village_gate.leaf_removed(79) or scene.gate_leaves.panels["80"].visible or static_fallen_visible():
		fail("The south door also laid plank 80 or the static copy")
		return
	walk_error = await walk_to(SOUTH, NORTH)
	if not walk_error.is_empty():
		fail(walk_error)
		return
	aim(LEAF79)
	await physics_frame
	if not scene.gate_leaves.interaction_hint().begins_with("E — Force gate"):
		fail("North door did not offer the force: '%s'" % scene.gate_leaves.interaction_hint())
		return
	press_e()
	await physics_frame
	if not scene.village_gate.leaf_removed(79) or not scene.gate_leaves.panels["80"].visible:
		fail("Forcing the north door did not lay plank 80")
		return
	if not scene.gate_leaves.panels["81"].visible or static_fallen_visible():
		fail("Both planks are not the gate-leaf copies alone")
		return
	print("PASS gate planks: walked to (-1176,-5247), the two planks were gone while the doors stood, and forcing both doors laid the planks down")
	quit(0)

func doors_up() -> bool:
	return not scene.village_gate.leaf_removed(78) and not scene.village_gate.leaf_removed(79)

func planks_down() -> bool:
	return scene.gate_leaves.panels["80"].visible or scene.gate_leaves.panels["81"].visible or static_fallen_visible()

func static_fallen_visible() -> bool:
	var ids: Array[int] = [80, 81]
	for id in ids:
		if scene.static_assemblies.is_present(id):
			return true
		var meshes: Array = scene.static_assemblies.stateful_meshes.get(id, [])
		if meshes.is_empty():
			return true
		for index in meshes.size():
			var mesh: MeshInstance3D = meshes[index]
			if mesh.visible:
				return true
	return false

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

func press_e() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	event.echo = false
	scene.gate_leaves._unhandled_input(event)
