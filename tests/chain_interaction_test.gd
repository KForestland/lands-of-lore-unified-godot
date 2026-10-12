extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/recovered_chain_cave_review.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	await physics_frame
	await physics_frame
	# Isolate the interaction gate from unknown cave visibility at an elevated fixture.
	scene.chain_sprite.global_position = Vector3(0, 100, 0)
	scene.camera.global_position = Vector3(0, 100, 1)
	scene.camera.look_at(scene.chain_sprite.global_position)
	assert(scene._can_interact())
	scene.camera.global_position.z = 2
	assert(not scene._can_interact())
	scene.camera.global_position.z = 1
	scene.camera.look_at(Vector3(1, 100, 1))
	assert(not scene._can_interact())
	scene.camera.look_at(scene.chain_sprite.global_position)
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 1, 0.1)
	collider.shape = box
	body.add_child(collider)
	body.position = Vector3(0, 100, 0.5)
	scene.add_child(body)
	await physics_frame
	await physics_frame
	assert(not scene._can_interact())
	body.collision_layer = 0
	await physics_frame
	await physics_frame
	assert(scene._can_interact())
	scene.chain_state.activate()
	assert(not scene._can_interact())
	scene.chain_state.reset()
	assert(scene._can_interact())
	assert(is_equal_approx(scene.chain_sprite.scale.y * scene.chain_sprite.texture.get_height(), 60.0))
	print("Chain interaction: reach, aim, obstruction, activation/reset and 60-unit height passed")
	scene.free()
	quit()
