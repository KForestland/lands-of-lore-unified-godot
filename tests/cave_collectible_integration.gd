extends "res://tests/walkthrough_save_integration.gd"

const Item = preload("res://scripts/lol2/cave_collectible.gd")
var reference_images: Dictionary = {}

func capture_state(label: String) -> void:
	var directory := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--collection-capture="):
			directory = argument.trim_prefix("--collection-capture=")
	if directory.is_empty(): return
	DirAccess.make_dir_recursive_absolute(directory)
	if label == "before":
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(directory.path_join("interaction_prompt.png"))
	view.hud.visible = false
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(directory)
	var images := {"resolved": root.get_texture().get_image(),
		"indices": view.index_view.get_texture().get_image(),
		"light": view.light_view.get_texture().get_image()}
	for name in images:
		images[name].save_png(directory.path_join(label + "_" + name + ".png"))
		if label == "before": reference_images[name] = images[name].get_data()
		elif label == "collected": check(images[name].get_data() != reference_images[name], "Collection changes " + name + " pixels")
		elif label == "restored": check(images[name].get_data() == reference_images[name], "Earlier save restores exact " + name + " pixels")
	view.hud.visible = true

func interact() -> void:
	await press(KEY_E)
	view._update_interaction()
	await process_frame

func aim_at_sample() -> void:
	# Use the reviewed floor-region viewpoint, then step the camera closer.
	view._position_glow_review()
	var target: Vector3 = view.collectible.target_position()
	var direction: Vector3 = (view.camera.global_position - target).normalized()
	view.player.global_position += target + direction * 48 - view.camera.global_position
	view.camera.look_at(target)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await physics_frame
	await physics_frame
	view._update_interaction()

func _run() -> void:
	check(OS.get_user_data_dir().get_file().begins_with("LoL2 Save Integration Test"), "Test data isolated")
	if failures:
		quit(1)
		return
	await open_cave()
	if "--collection-restart-read" in OS.get_cmdline_user_args():
		await press(KEY_F9)
		check(view.collectible.collected and not view.collectible.mesh.visible, "Restart restores collected object")
		check(view._save_state().collected == [Item.ID], "Restart restores exactly one item")
		await aim_at_sample()
		await interact()
		check(view._save_state().collected == [Item.ID], "Restart cannot duplicate item")
		DirAccess.remove_absolute(Save.DEFAULT_PATH)
		print("Collection restart: %d checks, %d failures" % [checks, failures])
		quit(1 if failures else 0)
		return
	await aim_at_sample()
	check(view.interaction_available, "Nearby aimed visible sample can be collected")
	if not view.interaction_available:
		print("Camera: ", view.camera.global_position, " target: ", view.collectible.target_position())
		var delta: Vector3 = view.collectible.target_position() - view.camera.global_position
		print("Input: ", Input.mouse_mode, " visible: ", view.collectible.mesh.is_visible_in_tree(), " distance: ", delta.length(), " aim: ", (-view.camera.global_basis.z).dot(delta.normalized()))
		var ray := PhysicsRayQueryParameters3D.create(view.camera.global_position, view.collectible.target_position(), 1, [view.player.get_rid()])
		print("Ray hit: ", view.get_world_3d().direct_space_state.intersect_ray(ray))
		quit(1)
		return
	var original_pose: Transform3D = view.player.global_transform
	var original_camera: Transform3D = view.camera.transform
	await capture_state("before")
	await press(KEY_F5)
	var uncollected_bytes := FileAccess.get_file_as_bytes(Save.DEFAULT_PATH)
	view.player.position += (view.camera.global_position - view.collectible.target_position()).normalized() * 200
	await interact()
	check(not view.collectible.collected, "Out of reach cannot collect")
	view.player.global_transform = original_pose
	view.camera.rotate_y(PI)
	await interact()
	check(not view.collectible.collected, "Looking away cannot collect")
	view.camera.transform = original_camera
	view.props_root.visible = false
	await interact()
	check(not view.collectible.collected, "Hidden props cannot be collected")
	view.props_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await interact()
	check(not view.collectible.collected, "Released mouse cannot collect")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 10, 10)
	shape.shape = box
	blocker.add_child(shape)
	view.add_child(blocker)
	blocker.global_position = view.camera.global_position.lerp(view.collectible.target_position(), 0.5)
	await physics_frame
	await physics_frame
	await interact()
	check(not view.collectible.collected, "Wall blocks collection")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	await interact()
	check(view.collectible.collected and not view.collectible.mesh.visible, "E collects and hides the original prop")
	check(view._save_state().collected == [Item.ID], "One stable collected-object ID")
	check(view.light_pairs.all(func(pair): return pair[1].visible == pair[0].is_visible_in_tree()), "Collection hides light mask")
	check(view.occluder_pairs.all(func(pair): return pair[1].visible == pair[0].is_visible_in_tree()), "Collection hides special mask")
	var glow_index: int = view.glow_records.find(Item.RECORD)
	check(view.light_materials.all(func(material): return material.get_shader_parameter("glow_active")[glow_index] == 0.0), "Collected sample no longer emits spill light")
	await capture_state("collected")
	await interact()
	check(view._save_state().collected == [Item.ID], "Repeated E does not duplicate collection")
	await press(KEY_R)
	await press(KEY_B)
	await press(KEY_B)
	check(not view.collectible.mesh.visible, "Reset and visibility toggles do not respawn sample")
	await press(KEY_F5)
	var collected_bytes := FileAccess.get_file_as_bytes(Save.DEFAULT_PATH)
	var file := FileAccess.open(Save.DEFAULT_PATH, FileAccess.WRITE)
	file.store_buffer(uncollected_bytes)
	file.close()
	await press(KEY_F9)
	check(not view.collectible.collected and view.collectible.mesh.visible, "Earlier save restores uncollected object")
	check(view.light_materials.all(func(material): return material.get_shader_parameter("glow_active")[glow_index] == 1.0), "Earlier save restores spill light")
	await capture_state("restored")
	file = FileAccess.open(Save.DEFAULT_PATH, FileAccess.WRITE)
	file.store_buffer(collected_bytes)
	file.close()
	await press(KEY_F9)
	check(view.collectible.collected and not view.collectible.mesh.visible, "Collected save removes object again")
	print("Collection integration: %d checks, %d failures" % [checks, failures])
	# Leave the isolated slot for the next process to verify.
	quit(1 if failures else 0)
