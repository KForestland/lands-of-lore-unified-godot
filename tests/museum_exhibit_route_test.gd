extends SceneTree
func _initialize(): run.call_deferred()
func run():
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 32
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Start fixture at gallery with the previously collected sword. No later repositioning.
	scene.player.position = Vector3(1900,32,-1454)
	scene.carried_collected.append(scene.SWORD_ITEM_ID)
	scene.sword_transfer.collect()
	scene.set_equipped_item(scene.SWORD_ITEM_ID)
	scene.camera.look_at(scene.gallery.painting.global_position)
	await physics_frame
	assert(scene.use_gallery())
	scene.camera.look_at(scene.gallery.lever.global_position)
	assert(scene.use_gallery())
	if not await walk_route(scene,"gallery_hourglass"): return
	scene.camera.look_at(scene.hourglass.global_position+Vector3(0,31,0))
	assert(scene.can_strike_hourglass() and scene.gallery.progress == 1)
	assert(scene.strike_hourglass())
	assert(not scene.gallery.gate_open)
	if not await walk_route(scene,"hourglass_wall"): return
	scene.camera.look_at(scene.escape_wall.global_position)
	for i in range(660):
		if scene.escape_wall.stage > 0: break
		await physics_frame
	assert(scene.gallery.progress == 0 and scene.escape_wall.stage == 1)
	for i in range(3): assert(scene.strike_escape_wall())
	if not await walk_points(scene,[[1460,-492]],"wall crossing"): return
	if not await walk_route(scene,"escape_dragon"): return
	assert(scene.hourglass.escaped)
	scene.player.rotation = Vector3.ZERO
	scene.camera.rotation = Vector3.ZERO
	print("Dragon door: ",scene.dragon_door.opened," progress=",scene.dragon_door.progress," position=",scene.dragon_door.position)
	assert(scene.dragon_door.opened and scene.dragon_door.progress == 1)
	assert(scene.can_enter_dragon())
	assert(scene.enter_dragon())
	scene.dragon_flight.close() # Existing skip behavior; playback tested separately.
	for i in range(5): await process_frame
	assert(current_scene.get_script().resource_path.ends_with("jungle_walkthrough.gd"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in range(90): await physics_frame
	assert(current_scene.player.is_on_floor() and current_scene.resets == 0)
	assert(current_scene.equipped_item == "museum:item11:Fine_Longsword")
	print("Continuous exhibit route passed: gallery lever, grate crossing/closure, hourglass, wall break, passage escape, dragon skip and jungle arrival; no repositioning after gallery fixture")
	quit()
func walk_route(scene, name: String) -> bool:
	var route = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/museum_%s_walk_route.json" % name))
	return await walk_points(scene,route.points,name)
func walk_points(scene, points: Array, label: String) -> bool:
	for i in range(points.size()):
		if i % 10 == 0: print(label," ",i,"/",points.size())
		var target := Vector2(points[i][0],points[i][1])
		var reached := false
		for step in range(480):
			await physics_frame
			if not scene.dragon_door.opened and scene.camera.global_position.distance_to(scene.dragon_door.global_position+Vector3(0,35,0)) < 90:
				scene.camera.look_at(scene.dragon_door.global_position+Vector3(0,35,0))
				if scene.can_open_dragon_door():
					var event := InputEventKey.new()
					event.keycode = KEY_E
					event.pressed = true
					Input.parse_input_event(event)
					Input.flush_buffered_events()
			var offset := target-Vector2(scene.player.position.x,scene.player.position.z)
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
			scene.check_exhibit_escape()
		if not reached:
			push_error("%s blocked at %d target %s player %s" % [label,i,target,scene.player.position])
			quit(1)
			return false
	return true
