extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/recovered_chain_cave_review.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	scene._start_walk()
	assert(scene.walk_player.active, "Actual chain area must have a clear walking spawn")
	scene.walk_player.automated = true
	for i in range(30):
		await physics_frame
	assert(scene.walk_player.is_on_floor(), "Spawn must settle on the recovered floor")
	assert(scene.camera.global_position.distance_to(scene.walk_player.global_position + Vector3.UP * 0.65) < 0.03)
	var eye: Vector3 = scene.camera.global_position
	scene.walk_player.test_direction = Vector2(0, -1)
	for i in range(12):
		await physics_frame
	scene.walk_player.test_direction = Vector2.ZERO
	assert(scene.camera.global_position.distance_to(eye) > 0.05, "Walk input should move the camera")
	# Aim precisely at the source chain after walking; exercise the shared interaction gate.
	var offset: Vector3 = scene.chain_sprite.global_position - scene.camera.global_position
	scene.walk_player.view_pitch = atan2(offset.y, Vector2(offset.x, offset.z).length())
	scene._update_camera()
	assert(scene._can_interact(), "Source chain should be reachable from the walking approach")
	assert(scene._strike_chain())
	assert(not scene._strike_chain())
	scene._reset_chain()
	assert(scene.short_sword_rule.remaining == 2)
	scene._stop_walk()
	assert(not scene.walk_player.active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	print("Chain walking: source spawn, grounded movement, camera, reachable strike, reset and orbit return passed")
	scene.free()
	quit()
