extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	assert(cave.walkthrough_ready and cave.checkpoint == 120)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in range(20): await physics_frame
	var mesh: MeshInstance3D = cave.stalagmites.plants[641]
	var target: Vector3 = mesh.to_global(mesh.mesh.center_offset)
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	for i in range(900):
		cave.player.look_at(Vector3(target.x,cave.player.global_position.y,target.z))
		cave.camera.look_at(target)
		await physics_frame
		if cave.stalagmites.target() == 641: break
	key.pressed = false
	Input.parse_input_event(key)
	print("Entrance walk native=",cave.player.global_position-cave.native_translation," target=",cave.stalagmites.target()," resets=",cave.resets)
	assert(cave.stalagmites.target() == 641 and cave.resets == 0,"Source entrance must reach first weapon without repositioning")
	var take := InputEventKey.new()
	take.keycode = KEY_E
	take.pressed = true
	cave._unhandled_input(take)
	await physics_frame
	await physics_frame
	assert(cave.stalagmites.collected == ["cave:prop641:harvest1:Stalagmite"])
	assert(cave.set_equipped_item(cave.stalagmites.collected[0]))
	cave.free()
	print("PASS source entrance-to-first-weapon walk: normal movement, actual E pickup, no repositioning/checkpoint jumps or supplied equipment")
	quit()
