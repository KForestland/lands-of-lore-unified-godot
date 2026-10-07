extends SceneTree
var scene: Node
func _initialize() -> void:
	_run.call_deferred()
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	scene._unhandled_input(event)
func _run() -> void:
	scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(240):
		await process_frame
		if scene.walkthrough_ready: break
	for i in range(5): await physics_frame
	var count: int = scene.fixtures[0].checkpoints.size()
	assert(count == 119)
	assert(scene.checkpoint == count)
	assert(scene.indexed_chain.can_strike())
	var approach: Vector3 = scene.player.global_position
	key(KEY_N)
	assert(scene.checkpoint == count+1)
	key(KEY_N)
	assert(scene.checkpoint == 0)
	key(KEY_P)
	assert(scene.checkpoint == count+1)
	key(KEY_P)
	assert(scene.checkpoint == count)
	key(KEY_P)
	assert(scene.checkpoint == count - 1)
	key(KEY_N)
	assert(scene.checkpoint == count)
	assert(scene.indexed_chain.strike())
	for i in range(280): await physics_frame
	key(KEY_N)
	key(KEY_P)
	scene.player.global_position += Vector3.UP * 20
	key(KEY_R)
	assert(scene.player.global_position.distance_to(approach) < 1)
	assert(scene.indexed_chain.state.door_dispatch_count == 1)
	for door in scene.indexed_doors: assert(door.opening_percent == 100)
	# Occupied spawn must leave both location and checkpoint unchanged.
	key(KEY_N)
	var previous: Vector3 = scene.player.global_position
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 80, 40)
	shape.shape = box
	blocker.add_child(shape)
	scene.add_child(blocker)
	blocker.global_position = approach
	await physics_frame
	scene.set_physics_process(false)
	previous = scene.player.global_position
	key(KEY_P)
	assert(scene.checkpoint == count+1)
	assert(scene.player.global_position == previous)
	blocker.free()
	await physics_frame
	key(KEY_P)
	assert(scene.checkpoint == count)
	var path := "user://tests/chain_checkpoint_%d.json" % Time.get_ticks_usec()
	assert(scene._quicksave(path).is_empty())
	assert(FileAccess.file_exists(path))
	assert(scene._quickload(path).is_empty())
	assert(scene.checkpoint == count and scene.indexed_chain.state.door_dispatch_count == 1)
	DirAccess.remove_absolute(path)
	print("Chain checkpoint: N/P wrap, return, R preserving event, occupied spawn rejection and save/load passed")
	scene.free()
	quit()
