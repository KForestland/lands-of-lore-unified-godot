extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(300):
		await process_frame
		if scene.walkthrough_ready: break
	assert(scene.walkthrough_ready)
	scene.set_physics_process(false)
	scene.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scene.hud.visible = false
	var records: Array = []
	for checkpoint in [82, 83, 84, 85]:
		scene._jump_checkpoint(checkpoint - 1)
		for direction in range(2):
			scene.player.rotation.y += PI if direction == 1 else 0.0
			for i in range(8): await process_frame
			await RenderingServer.frame_post_draw
			var path = "/home/bob/lol2_out/chamber_inspection_20260913/checkpoint_%d_%d.png" % [checkpoint, direction]
			assert(root.get_texture().get_image().save_png(path) == OK)
			records.append({"checkpoint": checkpoint, "direction": direction, "player": str(scene.player.global_position), "native_translation": str(scene.native_translation), "camera": str(scene.camera.global_transform), "image": path})
	for native_y in [18400, 18600]:
		scene.player.global_position = Vector3(-65, -295 + 32, -native_y) + scene.native_translation
		scene.player.rotation = Vector3.ZERO
		scene.camera.rotation = Vector3.ZERO
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		var path = "/home/bob/lol2_out/chamber_inspection_20260913/approach_%d.png" % native_y
		assert(root.get_texture().get_image().save_png(path) == OK)
		records.append({"native_y": native_y, "player": str(scene.player.global_position), "image": path, "scope": "Fixed inspection pose, not a walking test"})
	var file = FileAccess.open("/home/bob/lol2_out/chamber_inspection_20260913/poses.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "  "))
	print("Chamber location review: eight checkpoint and two center approach views captured; no story trigger changed")
	scene.free()
	quit()
