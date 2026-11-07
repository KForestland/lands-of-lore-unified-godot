extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	var wall = scene.escape_wall
	wall.set_process(false)
	assert(wall.visible and not wall.light_ray.visible and not wall.receive_hit())
	assert(scene.hourglass.receive_hit())
	scene.hourglass.set_process(false)
	wall.begin_decay()
	var delay: float = wall.reveal_wait
	assert(delay >= 5 and delay <= 10)
	wall.begin_decay()
	assert(wall.reveal_wait == delay)
	wall._process(delay)
	assert(wall.stage == 1 and wall.visible and wall.light_ray.visible)
	scene.player.position = Vector3(1350,32,-492)
	scene.camera.look_at(wall.global_position)
	await physics_frame
	assert(not scene.strike_escape_wall())
	scene.carried_collected.append(scene.SWORD_ITEM_ID)
	scene.sword_transfer.collect()
	scene.set_equipped_item(scene.SWORD_ITEM_ID)
	for form in [1,2]:
		scene.player_form=form
		assert(not scene.can_strike_escape_wall(),"Cursed form used a stored sword")
	scene.player_form=0
	assert(scene.can_strike_escape_wall())
	# Closed wall blocks a player-sized sweep along the passage.
	var start: Transform3D = scene.player.global_transform
	assert(scene.player.test_move(start,Vector3(100,0,0)))
	for expected in [2,3,4]:
		assert(scene.strike_escape_wall())
		assert(wall.stage == expected)
	assert(not scene.strike_escape_wall())
	assert(not scene.check_exhibit_escape())
	var escaped_once := 0
	for i in range(180):
		await physics_frame
		scene.player.velocity = Vector3(80,-1 if scene.player.is_on_floor() else scene.player.velocity.y-320.0/60,0)
		preload("res://scripts/lol2/walk_step.gd").try_step(scene.player,Vector3(80.0/60,0,0))
		scene.player.move_and_slide()
		if scene.check_exhibit_escape(): escaped_once += 1
		if scene.player.position.x > 1460: break
	print("Wall crossing position: ",scene.player.position)
	assert(scene.player.position.x > 1460)
	for i in range(90):
		await physics_frame
		scene.player.velocity = Vector3(0,-1 if scene.player.is_on_floor() else scene.player.velocity.y-320.0/60,0)
		scene.player.move_and_slide()
		if scene.check_exhibit_escape(): escaped_once += 1
	print("Escape landing: ",scene.player.position," grounded=",scene.player.is_on_floor())
	assert(escaped_once == 1 and scene.hourglass.escaped)
	assert(not scene.check_exhibit_escape())
	var stage: int = scene.hourglass.active_stage
	var wait: float = scene.hourglass.stage_wait
	scene.hourglass._process(1000.0)
	assert(scene.hourglass.active_stage == stage and scene.hourglass.stage_wait == wait)

	var path := "user://tests/escape_wall_%d.json" % OS.get_process_id()
	assert(scene.quicksave(path).is_empty())
	wall.restore_checkpoint({})
	assert(wall.stage == 0 and not wall.light_ray.visible)
	assert(scene.quickload(path).is_empty())
	assert(wall.stage == 4 and wall.visible and scene.hourglass.escaped)
	var saved: Dictionary = scene.Save.read_save(path).state
	saved.checkpoint.hourglass.escaped = "true"
	assert(not scene.Save.validate(saved).is_empty())
	saved.checkpoint.hourglass.escaped = true
	saved.checkpoint.escape_wall.stage = 1
	assert(not scene.Save.validate(saved).is_empty())
	scene.hourglass._process(1000.0)
	assert(scene.hourglass.active_stage == stage and scene.hourglass.stage_wait == wait)
	DirAccess.remove_absolute(path)
	if "--walk-to-dragon" in OS.get_cmdline_user_args():
		if not await walk_to_dragon(scene): return
	if "--capture-wall" in OS.get_cmdline_user_args():
		scene.player.position = Vector3(1350,32,-492)
		scene.camera.look_at(wall.global_position)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/museum_escape_wall.png")
	print("Escape wall passed: reveal timer, sword reach, three damage steps, repeat guard, source-region escape stop and save/load")
	quit()

func walk_to_dragon(scene) -> bool:
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 32
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var route = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/museum_escape_dragon_walk_route.json"))
	for i in range(route.points.size()):
		if i % 10 == 0: print("Escape passage walk ",i,"/",route.points.size())
		var target := Vector2(route.points[i][0],route.points[i][1])
		var reached := false
		for step in range(480):
			await physics_frame
			if not scene.dragon_door.opened and scene.camera.global_position.distance_to(scene.dragon_door.global_position+Vector3(0,35,0)) < 90:
				scene.camera.look_at(scene.dragon_door.global_position+Vector3(0,35,0))
				scene.open_dragon_door()
			var offset := target - Vector2(scene.player.position.x,scene.player.position.z)
			if offset.length() < 3:
				reached = true
				break
			var direction := offset.normalized()
			var dt: float = scene.get_physics_process_delta_time()
			scene.player.velocity = Vector3(direction.x*minf(80,offset.length()/dt),-1 if scene.player.is_on_floor() else scene.player.velocity.y-320*dt,direction.y*minf(80,offset.length()/dt))
			if preload("res://scripts/lol2/walk_step.gd").try_step(scene.player,Vector3(scene.player.velocity.x,0,scene.player.velocity.z)*dt):
				scene.player.velocity.x = 0
				scene.player.velocity.z = 0
			scene.player.move_and_slide()
		if not reached:
			push_error("Escape route blocked at %d, region %s, target %s, player %s" % [i,route.regions[i],target,scene.player.position])
			quit(1)
			return false
	scene.player.rotation = Vector3.ZERO
	scene.camera.rotation = Vector3.ZERO
	assert(scene.can_enter_dragon())
	assert(scene.hourglass.escaped and scene.hourglass.active_stage == 0)
	print("Escape passage to dragon passed:55 source regions with normal capsule steps, no debug flight or position jumps")
	return true
