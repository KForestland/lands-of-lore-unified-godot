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
	for i in range(5): await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.player.global_position = Vector3(-65,-258,-16790) + scene.native_translation
	scene.player.velocity = Vector3.ZERO
	scene.player.rotation = Vector3.ZERO
	scene.camera.rotation = Vector3.ZERO
	scene.flying = false
	if "--river-capture" in OS.get_cmdline_user_args():
		scene.hud.visible = false
		scene.camera.rotation.x = -0.35
		for i in range(5): await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("/home/bob/lol2_out/chamber_route_20260913/deck.png") == OK)
		scene.camera.rotation.x = 0.0
		if "--river-capture-only" in OS.get_cmdline_user_args():
			scene.free()
			quit()
			return
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	var previous := 0.0
	var stalled := 0
	for i in range(1800):
		# Keep the scripted forward route independent of desktop capture motion.
		scene.player.rotation = Vector3.ZERO
		scene.camera.rotation = Vector3.ZERO
		await physics_frame
		var p: Vector3 = scene.player.global_position - scene.native_translation
		if i % 120 == 0: print("River route tick ", i, " native ", p, " grounded ", scene.player.is_on_floor())
		if absf(p.z - previous) < 0.01: stalled += 1
		else: stalled = 0
		previous = p.z
		if scene.chamber_arrival_state == "playing": break
		if stalled > 120 or scene.resets > 0: break
	key.pressed = false
	Input.parse_input_event(key)
	var passed: bool = scene.chamber_arrival_state == "playing" and scene.resets == 0
	print("River-to-chamber route passed=", passed, " final native=", scene.player.global_position - scene.native_translation)
	if not passed:
		for i in range(scene.player.get_slide_collision_count()):
			var hit = scene.player.get_slide_collision(i)
			print("Contact ", hit.get_position() - scene.native_translation, " normal ", hit.get_normal())
	if is_instance_valid(scene.video_overlay): scene.video_overlay.review.close()
	await process_frame
	scene.free()
	quit(0 if passed else 1)
