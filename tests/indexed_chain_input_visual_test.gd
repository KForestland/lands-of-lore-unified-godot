extends SceneTree
var scene: Node
const OUT = "/home/bob/lol2_out/indexed_door_visual_20260913"
func _initialize() -> void:
	_run.call_deferred()
func press_e(echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.physical_keycode = KEY_E
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)
	await physics_frame
	await physics_frame
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	Input.parse_input_event(event)
func shot(label: String) -> void:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT + "/" + label + ".png") == OK)
func _run() -> void:
	scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(240):
		await process_frame
		if scene.walkthrough_ready: break
	assert(scene.walkthrough_ready and scene.indexed_chain != null)
	await physics_frame
	await physics_frame
	assert(scene._position_chain_approach())
	for i in range(30): await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await press_e()
	assert(not scene.indexed_chain.state.started, "Released mouse must reject E")
	for cycle in range(2):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Requires a rendered display for captured input")
		assert(scene.indexed_chain.can_strike())
		await press_e(true)
		assert(not scene.indexed_chain.state.started, "Echo must not strike")
		await press_e()
		assert(scene.indexed_chain.state.started, "E must enter the real interaction path")
		await press_e()
		for i in range(280): await physics_frame
		assert(scene.indexed_chain.state.door_dispatch_count == 1)
		for door in scene.indexed_doors: assert(door.opening_percent == 100)
		assert(not scene.collectible.collected, "Chain input must not collect unrelated sample")
		scene.indexed_chain.reset()
		for i in range(3): await physics_frame
		for door in scene.indexed_doors: assert(door.opening_percent == 0)
	# Fixed inspection camera per doorway; sample exact poses without event ticking.
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Physics normally refreshes these flags; frozen inspection must clear them.
	scene.interaction_available = false
	scene.interaction_requested = false
	DirAccess.make_dir_recursive_absolute(OUT)
	var saved_camera: Transform3D = scene.camera.global_transform
	for n in range(2):
		var door = scene.indexed_doors[n]
		var center := Vector3.ZERO
		var points: PackedVector3Array = door.pose_points(0)
		for point in points: center += door.to_global(point) / points.size()
		var eye := Vector3(1169.5, -159, -11580) if n == 0 else Vector3(1242.5, -159, -11651)
		scene.camera.global_position = eye + scene.native_translation
		scene.camera.look_at(center, Vector3.UP)
		for pose in [0, 50, 100]:
			for panel in scene.indexed_doors: panel.set_opening(pose)
			await shot("door%d_%d" % [door.original_record, pose])
	scene.camera.global_transform = saved_camera
	print("Indexed E input: released-mouse/echo rejection, two complete cycles, duplicate protection and sample isolation passed; six door views captured")
	scene.free()
	quit()
