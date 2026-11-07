extends SceneTree
func _initialize() -> void: call_deferred("run")
func press(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func run() -> void:
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	for frame in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	assert(cave.walkthrough_ready)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Local reproduction of the naturally reached pool bank, not full-route proof.
	cave.player.global_position = Vector3(-589,-175,-9529)+cave.native_translation
	cave.player.velocity = Vector3.ZERO
	for frame in range(20): await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	press(KEY_SPACE,true)
	await physics_frame
	press(KEY_SPACE,false)
	assert(not cave.jump_requested and cave.player.velocity.y <= 0,"Released mouse must not launch a jump")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	press(KEY_W,true)
	for frame in range(60):
		cave.player.look_at(Vector3(-570,cave.player.global_position.y-cave.native_translation.y,-9620)+cave.native_translation)
		cave.camera.rotation = Vector3.ZERO
		await physics_frame
	var before: Vector3 = cave.player.global_position-cave.native_translation
	assert(before.z > -9550 and cave.player.is_on_floor(),"Ordinary walk must remain blocked at the pool bank")
	press(KEY_SPACE,true)
	await physics_frame
	press(KEY_SPACE,false)
	for frame in range(10): await physics_frame
	assert(not cave.player.is_on_floor() and cave.player.velocity.y > 0,"Space must launch a grounded jump")
	var ascending: float = cave.player.velocity.y
	press(KEY_SPACE,true)
	await physics_frame
	press(KEY_SPACE,false)
	await physics_frame
	assert(cave.player.velocity.y < ascending,"No second jump in midair")
	for frame in range(100):
		cave.player.look_at(Vector3(-570,cave.player.global_position.y-cave.native_translation.y,-9690)+cave.native_translation)
		cave.camera.rotation = Vector3.ZERO
		await physics_frame
	press(KEY_W,false)
	var after: Vector3 = cave.player.global_position-cave.native_translation
	print("Pool jump before=",before," after=",after," grounded=",cave.player.is_on_floor())
	assert(after.z < -9600 and after.y > -160 and cave.player.is_on_floor() and cave.resets == 0,"Jump must clear the bank and land on original geometry")
	cave.free()
	print("PASS pool bank: walking blocked, Space jump exits, midair jump rejected, grounded landing without geometry changes")
	quit()
