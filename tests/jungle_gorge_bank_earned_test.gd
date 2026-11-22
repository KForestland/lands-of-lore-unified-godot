extends SceneTree
## Owner r17 17-01-09 at Jungle (3105,-4349), looking across the south bank: a hidden wall, and the puzzle
## suspected below the clip. Region 3331's wall is drawn only up to the gorge opening. The walk stays on the bank.
const Form = preload("res://scripts/lol2/player_form_body.gd")
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL bank: ", message)
	quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for _i in 1500:
		await process_frame
		if scene.get("ready_for_review"):
			break
	if not scene.get("ready_for_review"):
		fail("Jungle not ready")
		return
	var start := Vector2(3105.49, -4349.05)
	var target := Vector2(3105.49, -4200.0)
	plant(start)
	for _i in 20:
		await physics_frame
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
	var body: CharacterBody3D = scene.player
	var floor_y: float = body.global_position.y
	if floor_y < 20.0 or floor_y > 40.0:
		fail("Not standing on the bank at %s" % body.global_position)
		return
	var stuck := 0
	var previous := body.global_position
	var arrived := false
	for _step in 700:
		var flat := target - Vector2(body.global_position.x, body.global_position.z)
		if flat.length() < 8.0:
			arrived = true
			break
		await physics_frame
		scene.move_grounded(Vector3(flat.x, 0.0, flat.y).normalized(), 1.0 / 60.0)
		if body.global_position.y < floor_y - 20.0:
			fail("Fell off the bank at %s" % body.global_position)
			return
		if body.global_position.distance_to(previous) < 0.05:
			stuck += 1
			if stuck >= 25:
				fail("Hidden wall still stops the bank at %s" % body.global_position)
				return
		else:
			stuck = 0
			previous = body.global_position
	if not arrived:
		fail("Did not cross the bank to %s, stopped at %s" % [target, body.global_position])
		return
	if body.global_position.z <= -4334.0:
		fail("Still south of the gorge wall at %s" % body.global_position)
		return
	print("PASS bank: walked from (3105,-4349) across the gorge wall and stayed on the bank")
	quit(0)

func plant(at: Vector2) -> void:
	var body: CharacterBody3D = scene.player
	var top := Vector3(at.x, 80.0, at.y)
	var query := PhysicsRayQueryParameters3D.create(top, top - Vector3.UP * 200.0, 1, [body.get_rid()])
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	var ground := 0.0
	if not hit.is_empty():
		ground = hit.position.y
	body.global_position = Vector3(at.x, ground + Form.FOOT_OFFSET, at.y)
	body.velocity = Vector3.ZERO
	body.rotation.y = 3.081611
	scene.camera.rotation = Vector3(0.042007, 0.0, 0.0)
