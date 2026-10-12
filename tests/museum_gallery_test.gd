extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	var gallery = scene.gallery
	gallery.set_physics_process(false)
	assert(not gallery.pull_lever())
	scene.player.position = Vector3(1900,32,-1454)
	scene.camera.look_at(gallery.painting.global_position)
	await physics_frame
	assert(scene.gallery_target() == "painting")
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	assert(gallery.painting_moved and gallery.lever.visible and not gallery.gate_open)
	scene.camera.look_at(gallery.lever.global_position)
	assert(scene.gallery_target() == "lever")
	scene.interface_hud.set_cursor(true)
	assert(not scene.use_gallery())
	scene.interface_hud.set_cursor(false)
	assert(scene.use_gallery())
	assert(not scene.use_gallery())
	scene.player.position = Vector3(1128,32,-920)
	await physics_frame
	assert(scene.player.test_move(scene.player.global_transform,Vector3(0,0,-55)))
	gallery._physics_process(1.2)
	await physics_frame
	assert(not scene.player.test_move(scene.player.global_transform,Vector3(0,0,-55)))
	var path := "user://tests/gallery_%d.json" % OS.get_process_id()
	assert(scene.quicksave(path).is_empty())
	gallery.restore_checkpoint({})
	assert(not gallery.painting_moved and not gallery.gate_open)
	assert(scene.quickload(path).is_empty())
	assert(gallery.painting_moved and gallery.gate_open and gallery.progress == 1)
	var saved: Dictionary = scene.Save.read_save(path).state
	saved.checkpoint.gallery.painting_moved = false
	assert(not scene.Save.validate(saved).is_empty())
	# Source hourglass closure lowers only the grate; lever remains operated.
	gallery.close_for_hourglass()
	assert(gallery.lever_pulled and not gallery.gate_open)
	gallery._physics_process(0.6)
	assert(is_equal_approx(gallery.progress,0.5))
	assert(scene.quicksave(path).is_empty())
	gallery.restore_checkpoint({})
	assert(scene.quickload(path).is_empty())
	assert(gallery.lever_pulled and not gallery.gate_open and is_equal_approx(gallery.progress,0.5))
	gallery._physics_process(0.6)
	await physics_frame
	assert(scene.player.test_move(scene.player.global_transform,Vector3(0,0,-55)))
	DirAccess.remove_absolute(path)
	if "--capture-gallery" in OS.get_cmdline_user_args():
		scene.player.position = Vector3(1900,32,-1454)
		scene.camera.look_at(gallery.lever.global_position)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/museum_gallery.png")
	print("Gallery passed: painting E reveals lever, UI guard, lever raises collision grate, save/load")
	quit()
