extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(false)
	# Source 60-unit lip: region763 floor-1011 -> region972 floor-951.
	scene.player.position = Vector3(-3707,-979,-7110)
	for frame in range(12):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	assert(scene.player.is_on_floor())
	for frame in range(25):
		await physics_frame
		scene.move_grounded(Vector3.LEFT,scene.player.get_physics_process_delta_time())
	assert(scene.player.position.x > -3731 and scene.player.position.y < -978)
	assert(scene.request_jump() and not scene.request_jump())
	var airborne := false
	var landed := false
	for frame in range(150):
		await physics_frame
		scene.move_grounded(Vector3.LEFT if scene.player.position.x > -3750 else Vector3.ZERO,scene.player.get_physics_process_delta_time())
		if not scene.player.is_on_floor():
			airborne = true
			assert(not scene.request_jump())
		if airborne and scene.player.is_on_floor() and scene.player.position.y > -920:
			landed = true
			break
	assert(landed and scene.resets == 0,"Jump failed: "+str(scene.player.position))
	# Both directions across the source lift/upper-landing gap, using Shift speed.
	scene.player.position = Vector3(-2496,-203,-7614)
	scene.player.velocity = Vector3.ZERO
	for frame in range(12):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	assert(scene.player.is_on_floor())
	for target_x in [-2338.0,-2520.0]:
		if target_x == -2520.0:
			for frame in range(15):
				await physics_frame
				scene.move_grounded(Vector3.LEFT,scene.player.get_physics_process_delta_time())
		assert(scene.request_jump())
		var crossed := false
		for frame in range(180):
			await physics_frame
			var offset: float = target_x-scene.player.position.x
			var direction := Vector3(signf(offset),0,0) if absf(offset)>2 else Vector3.ZERO
			scene.move_grounded(direction,scene.player.get_physics_process_delta_time(),true)
			if absf(offset)<2 and scene.player.is_on_floor():
				crossed = true
				break
		assert(crossed and absf(scene.player.position.y+203)<0.2,"Lift gap jump failed: "+str(scene.player.position))
	scene.free()
	print("PASS: Hive jump clears source 60-unit lip and lift gap both ways; pending and airborne re-jumps rejected")
	quit()
