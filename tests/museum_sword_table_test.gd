extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.sword_transfer.set_process(false)
	scene.sword_transfer.restart()
	scene.sword_transfer.advance(4)
	scene.player.position = Vector3(-4222, 32, -1050)
	scene.camera.look_at(scene.sword_transfer.TABLE_SWORD)
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3(-4222,51,-1095),Vector3(-4222,40,-1095))
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	assert(hit.collider == scene.sword_table and is_equal_approx(hit.position.y,47.5))
	assert(scene.can_take_sword())
	var blocked := false
	for step in range(45):
		scene.player.velocity = Vector3(0,0,-80)
		scene.player.move_and_slide()
		for index in scene.player.get_slide_collision_count():
			if scene.player.get_slide_collision(index).get_collider() == scene.sword_table:
				blocked = true
		await physics_frame
	assert(blocked and scene.player.position.z > -1085)
	scene.camera.look_at(scene.sword_transfer.TABLE_SWORD)
	assert(scene.can_take_sword())
	if "--capture-table" in OS.get_cmdline_user_args():
		scene.player.position = Vector3(-4267,32,-1038)
		scene.camera.look_at(scene.sword_transfer.TABLE_SWORD)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/bob/lol2_out/museum_sword_transfer_review_20260914/godot_sword_table.png")
	assert(scene.take_sword())
	assert(is_instance_valid(scene.sword_table))
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	print("Sword table passed: support height, approach collision, unobstructed pickup, table remains after collection")
	quit()
