extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func _run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	await process_frame
	var hud = scene.interface_hud
	assert(hud.cursor_texture.get_size() == Vector2(18, 28))
	assert(not hud.cursor_active)
	key(KEY_M)
	assert(hud.cursor_active and hud.sheet.visible and hud.atlas.visible)
	assert(hud.atlas_opened_from_game)
	key(KEY_M)
	assert(not hud.cursor_active and not hud.sheet.visible)
	key(KEY_M)
	key(KEY_ESCAPE)
	assert(not hud.cursor_active and not hud.sheet.visible)
	key(KEY_TAB)
	key(KEY_M)
	assert(not hud.atlas_opened_from_game)
	key(KEY_M)
	assert(hud.cursor_active and not hud.sheet.visible)
	assert(hud.cursor_active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	# Actual GUI click on the Atlas button must not recapture the mouse.
	var button: Button = hud.buttons[1]
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = button.get_global_rect().get_center()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		Input.flush_buffered_events()
	assert(hud.sheet.visible and hud.atlas.visible and not hud.atlas.edges.is_empty())
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	var map = hud.atlas
	var anchor: Vector2 = map.size * Vector2(0.3, 0.4)
	var reference: Vector2 = map.bounds.position
	var before: Vector2 = map.map_point(reference)
	var wheel := InputEventMouseButton.new()
	wheel.position = map.global_position + anchor
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	Input.flush_buffered_events()
	assert(is_equal_approx(map.zoom, 1.25))
	assert(map.map_point(reference).is_equal_approx(anchor + (before - anchor) * 1.25))
	var camera_rotation: Vector3 = scene.camera.rotation
	var player_rotation: Vector3 = scene.player.rotation
	var drag := InputEventMouseMotion.new()
	drag.position = wheel.position
	drag.relative = Vector2(25, -12)
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	var old_pan: Vector2 = map.pan
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	assert(map.pan.is_equal_approx(old_pan + drag.relative))
	assert(scene.camera.rotation == camera_rotation and scene.player.rotation == player_rotation)
	hud.atlas_controls.get_child(2).pressed.emit()
	var player_position: Vector3 = scene.player.global_position
	assert(map.map_point(Vector2(player_position.x, player_position.z)).is_equal_approx(map.size / 2))
	map.zoom_at(1000, anchor)
	assert(map.zoom == 12.0)
	map.zoom_at(0.0001, anchor)
	assert(map.zoom == 1.0)
	hud.atlas_controls.get_child(3).pressed.emit()
	assert(map.zoom == 1.0 and map.pan == Vector2.ZERO)
	key(KEY_ESCAPE)
	assert(not hud.sheet.visible and hud.cursor_active)
	# Portrait textures must pass actual clicks through to the character button.
	assert(hud.buttons[0].get_child_count() == 2)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = hud.buttons[0].global_position + Vector2(120, 60)
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		Input.flush_buffered_events()
	assert(hud.sheet.visible and not hud.atlas.visible)
	hud.buttons[2].pressed.emit()
	assert(paused and is_instance_valid(scene.inventory))
	key(KEY_ESCAPE)
	await process_frame
	await process_frame
	assert(not paused and hud.cursor_active and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	hud.buttons[2].pressed.emit()
	key(KEY_TAB)
	await process_frame
	await process_frame
	assert(not paused and not hud.cursor_active)
	key(KEY_TAB)
	hud.buttons[1].pressed.emit()
	if "--capture-interface" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/bob/lol2_out/museum_sword_transfer_review_20260914/godot_interface.png")
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	print("Museum interface passed: Tab toggle, GUI click, atlas geometry, character panel, nested inventory close and Tab return")
	quit()
