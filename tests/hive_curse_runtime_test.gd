extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	Engine.time_scale = 16
	Engine.physics_ticks_per_second = 960
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	root.grab_focus()
	for frame in range(3): await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Supplied gate position only; leave the production physics/curse nodes running.
	scene.player.position = Vector3(-1041.5,-203,-8184.75)
	scene.get_node("Warriors").health=7
	var warning_seen := false
	for tick in range(15000):
		await physics_frame
		if scene.curse.state.phase == 1:
			warning_seen = true
			assert(scene.curse.state.target == 2)
			assert(scene.get_node("Warriors").health==7,"Warning healed before actual morph")
		if scene.player_form == 2: break
	if not warning_seen or scene.player_form != 2:
		push_error("Production curse failed: position=%s gate=%s curse=%s active=%s mouse=%s" % [scene.player.position,scene.hive_curse.checkpoint,scene.curse.snapshot(),scene.curse.active(),Input.mouse_mode])
		scene.free()
		quit(1)
		return
	assert(scene.get_node("Warriors").health==30,"Hive morph did not restore active health")
	assert(scene.hive_curse.checkpoint.enabled and scene.curse.state.duration >= 120)
	assert(scene.open_inventory())
	await process_frame
	var timer: Dictionary = scene.hive_curse.checkpoint.duplicate(true)
	var curse: Dictionary = scene.curse.snapshot()
	for frame in range(20): await process_frame
	assert(scene.hive_curse.checkpoint == timer and scene.curse.snapshot() == curse,"Inventory failed to suspend curse clocks")
	scene.inventory.close()
	for frame in range(3): await process_frame
	assert(scene.hive_curse.checkpoint.remaining < timer.remaining)
	scene.free()
	print("PASS: production Hive region admission, unshortened countdown, warning, lizard body and inventory pause/resume")
	quit()
