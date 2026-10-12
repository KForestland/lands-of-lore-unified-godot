extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	var prop = scene.get_node("MuseumHourglass226")
	scene.player.position = Vector3(1332,32,-590)
	scene.player.rotation = Vector3.ZERO
	scene.camera.look_at(Vector3(1332,41,-663))
	await physics_frame
	var mouse := Input.mouse_mode
	var children: int = scene.get_child_count()
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for i in range(3): await process_frame
	assert(not paused and Input.mouse_mode == mouse)
	assert(scene.get_child_count() == children and prop.frame == 0)
	var position: Vector3 = prop.position
	for target in [0,99,100,199,200,299]:
		prop.set_animation_frame(target)
		assert(prop.frame == target and prop.current_page == target / 100)
		assert(prop.material_override.uv1_scale == Vector3(0.1,0.1,1.0))
		assert(prop.material_override.uv1_offset.is_equal_approx(Vector3(float(target % 10)/10.0,float((target % 100)/10)/10.0,0)))
		assert(prop.position == position and prop.mesh.size == Vector2(100,62))
	prop.set_animation_frame(240)
	for i in range(3): await process_frame
	if "--capture-hourglass" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/bob/lol2_out/museum_progression_20260914/hourglass_in_world.png")
	assert(prop.frame == 240) # No invented autoplay or destruction countdown.
	prop.set_process(false)
	var completed: Array[int] = []
	prop.stage_finished.connect(func(stage: int): completed.append(stage))
	assert(not prop.play_stage(-1) and not prop.play_stage(4))
	for stage in range(4):
		assert(prop.play_stage(stage))
		assert(prop.frame == stage * 75)
		assert(not prop.play_stage((stage + 1) % 4))
		prop._process(4.99)
		assert(prop.frame == stage * 75 + 74 and prop.stage_playing)
		prop._process(0.02)
		assert(not prop.stage_playing and completed.size() == stage + 1)
		prop._process(100.0)
		assert(prop.frame == stage * 75 + 74 and completed.size() == stage + 1)
	assert(completed == [0,1,2,3])
	for stage in range(4):
		var command := PackedByteArray([8,3,226,0,10,0,stage,0])
		assert(prop.apply_stage_command(command))
		assert(prop.frame == stage * 75)
		prop._process(5.0)
	assert(not prop.apply_stage_command(PackedByteArray([8,3,226,0,10,0,4,0])))
	assert(not prop.apply_stage_command(PackedByteArray([8,3,225,0,10,0,0,0])))
	assert(not prop.apply_stage_command(PackedByteArray([14,3,226,0,3,0,0,0])))
	assert(not prop.apply_stage_command(PackedByteArray()))
	assert(prop.play_stage(0))
	prop.set_process(true)
	paused = true
	for i in range(4): await process_frame
	assert(prop.stage_elapsed == 0.0 and prop.frame == 0)
	paused = false
	for i in range(4): await process_frame
	assert(prop.stage_elapsed > 0.0)
	prop.set_process(false)
	prop.restore_checkpoint({})
	assert(not scene.strike_hourglass()) # No equipped weapon.
	scene.carried_collected.append(scene.SWORD_ITEM_ID)
	assert(scene.set_equipped_item(scene.SWORD_ITEM_ID))
	for form in [1,2]:
		scene.player_form=form
		assert(not scene.can_strike_hourglass(),"Cursed form used a stored sword")
	scene.player_form=0
	assert(scene.can_strike_hourglass())
	scene.interface_hud.set_cursor(true)
	assert(not scene.strike_hourglass())
	scene.interface_hud.set_cursor(false)
	paused = true
	assert(not scene.strike_hourglass())
	paused = false
	scene.player.rotation.y = PI
	assert(not scene.strike_hourglass())
	scene.player.rotation.y = 0
	var blocker := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100,100,4)
	collision.shape = box
	blocker.add_child(collision)
	scene.add_child(blocker)
	blocker.global_position = Vector3(1332,41,-630)
	await physics_frame
	await physics_frame
	assert(not scene.strike_hourglass()) # No strikes through walls.
	blocker.queue_free()
	await physics_frame
	await physics_frame
	scene.gallery.move_painting()
	scene.gallery.pull_lever()
	scene.gallery._physics_process(1.2)
	assert(scene.gallery.gate_open)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	assert(prop.activated and prop.active_stage == 0)
	assert(not scene.gallery.gate_open and scene.gallery.lever_pulled)
	assert(not scene.strike_hourglass())
	prop._process(2.0)
	scene.sword_transfer.collect()
	var save_path := "user://tests/hourglass_%d.json" % OS.get_process_id()
	assert(scene.quicksave(save_path).is_empty())
	prop.restore_checkpoint({})
	assert(scene.quickload(save_path).is_empty())
	assert(prop.activated and prop.frame == 30 and prop.stage_playing)
	var state: Dictionary = scene.Save.read_save(save_path).state
	state.checkpoint.hourglass.elapsed = 6
	assert(not scene.Save.validate(state).is_empty())
	state.checkpoint.erase("hourglass")
	assert(scene.Save.validate(state).is_empty()) # Older museum saves remain valid.
	scene.apply_save(state)
	assert(not prop.activated and prop.frame == 0)
	assert(scene.quickload(save_path).is_empty())
	DirAccess.remove_absolute(save_path)
	var saved: Dictionary = prop.checkpoint()
	prop.restore_checkpoint({})
	assert(not prop.activated and prop.frame == 0)
	prop.restore_checkpoint(saved)
	assert(prop.activated and prop.frame == 30 and prop.stage_playing)
	prop.advance_animation(100.0)
	assert(prop.frame == 74 and not prop.stage_playing)
	assert(not scene.strike_hourglass()) # One-time source latch survives completion.
	prop.restore_checkpoint(prop.checkpoint())
	assert(prop.frame == 74 and not prop.stage_playing)
	# Authored clock: exact boundary, large delta and serialized intermediate stage.
	prop.restore_checkpoint({"activated":true,"elapsed":5.0,"stage":0,"wait":10.0})
	prop.set_process(true)
	paused = true
	for i in range(4): await process_frame
	assert(prop.stage_wait == 10.0 and prop.frame == 74)
	paused = false
	prop.set_process(false)
	prop._process(9.99)
	assert(prop.active_stage == 0 and prop.frame == 74)
	prop._process(0.02)
	assert(prop.active_stage == 1 and prop.frame == 75)
	assert(prop.stage_wait >= 19.98 and prop.stage_wait <= 30)
	var timer_state: Dictionary = prop.checkpoint()
	prop.restore_checkpoint(timer_state)
	assert(prop.active_stage == 1 and is_equal_approx(prop.stage_wait,timer_state.wait))
	prop._process(prop.stage_wait)
	prop._process(prop.stage_wait)
	prop._process(5.0)
	assert(prop.active_stage == 3 and prop.frame == 299 and not prop.stage_playing)
	assert(prop.stage_wait == 0 and not paused)
	assert(prop.finish_escape())
	scene.escape_wall.restore_checkpoint({"stage":4,"wait":-1})
	prop._process(1000.0)
	assert(prop.frame == 299 and not prop.failed) # Escaping cancels failure.
	assert(scene.quicksave(save_path).is_empty())
	assert(scene.quickload(save_path).is_empty())
	assert(prop.active_stage == 3 and prop.frame == 299)
	DirAccess.remove_absolute(save_path)
	print("Hourglass object passed: E opens no panel, world remains active, frame selection and atlas boundaries preserve placement; four source stages, provisional scheduler, pause, wall/menu guards, one-shot activation and save/load passed")
	quit()
