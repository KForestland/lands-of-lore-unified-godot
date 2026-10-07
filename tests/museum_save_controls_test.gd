extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func click_button(button: Button) -> void:
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
func _run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.sword_transfer.set_process(false)
	var hud = scene.interface_hud
	hud.save_path = "user://tests/museum_controls_%d.json" % Time.get_ticks_usec()
	hud.set_cursor(true)
	hud.open_page("character")
	await process_frame
	await process_frame
	click_button(hud.load_button)
	assert(hud.save_status.text.begins_with("Load failed:") and hud.sheet.visible)
	var saved_position: Vector3 = scene.player.position
	click_button(hud.save_button)
	assert(hud.save_status.text == "Museum saved.")
	assert(FileAccess.file_exists(hud.save_path))
	assert(hud.cursor_active and hud.sheet.visible)
	scene.player.position.x += 10
	click_button(hud.load_button)
	assert(scene.player.position.is_equal_approx(saved_position))
	assert(not hud.cursor_active and not hud.sheet.visible)
	hud.set_cursor(true)
	hud.open_page("atlas")
	assert(not hud.character_controls.visible)
	hud.open_page("character")
	assert(hud.character_controls.visible)
	if "--capture-save-controls" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/bob/lol2_out/museum_sword_transfer_review_20260914/godot_character_save.png")
	DirAccess.remove_absolute(hud.save_path)
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	print("Save controls passed: actual mouse clicks, missing save feedback, save, load restores position/gameplay, page isolation")
	quit()
