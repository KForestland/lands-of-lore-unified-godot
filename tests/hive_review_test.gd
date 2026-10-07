extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	var data = JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
	assert(scene.face_count == data.faces.size())
	for arrival in data.arrivals:
		scene.start = Vector3(arrival.review_start[0], arrival.review_start[1], arrival.review_start[2])
		var capsule = scene.player.get_child(0).shape
		capsule.radius = 8.0 if arrival.entry == 1 else 4.0
		capsule.height = 64.0 if arrival.entry == 1 else 16.0
		if arrival.entry == 2: scene.start.y = -226.0
		scene.reset_position()
		for i in range(90): await physics_frame
		assert(scene.player.is_on_floor(), "Hive arrival must settle on floor")
		assert(scene.resets == 0)
		assert(Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(arrival.godot_xz[0],arrival.godot_xz[1])) < 1.0)
		print("Hive entry ", arrival.entry, " grounded at ", scene.player.position)
	if "--capture-hive" in OS.get_cmdline_user_args():
		scene.start = Vector3(848,24,-4447)
		scene.player.get_child(0).shape.radius = 8
		scene.player.get_child(0).shape.height = 64
		scene.reset_position()
		scene.player.rotation.y = PI
		scene.camera.rotation.x = -0.4
		for i in range(30): await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/bob/lol2_out/hive_geometry_20260914/textured_review.png")
	scene.queue_free()
	await process_frame
	quit()
