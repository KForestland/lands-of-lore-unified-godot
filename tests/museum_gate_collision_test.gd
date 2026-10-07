extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var gate = load("res://scripts/lol2/museum_gate.gd").new()
	root.add_child(gate)
	gate.position = Vector3.ZERO
	gate.set_physics_process(false)
	var player := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 8
	capsule.height = 64
	collision.shape = capsule
	player.add_child(collision)
	root.add_child(player)
	player.position = Vector3(0,32,-30)
	await physics_frame
	await physics_frame
	var hit := player.move_and_collide(Vector3(0,0,60))
	assert(hit != null and hit.get_collider() == gate.pivot)
	assert(player.position.z < -8)
	var hinge: Vector3 = gate.pivot.global_position
	gate.open()
	gate.advance(0.6)
	assert(gate.pivot.global_position == hinge)
	assert(is_equal_approx(gate.progress, 0.5))
	gate.advance(0.6)
	player.position = Vector3(0,32,-30)
	await physics_frame
	await physics_frame
	assert(player.move_and_collide(Vector3(0,0,60)) == null)
	assert(is_equal_approx(player.position.z,30))
	gate.reset()
	player.position = Vector3(0,32,-30)
	await physics_frame
	await physics_frame
	assert(player.move_and_collide(Vector3(0,0,60)) != null)
	print("Museum gate collision passed: closed blocks capsule, fixed hinge, open allows passage, reset blocks")
	player.free()
	gate.free()
	quit()
