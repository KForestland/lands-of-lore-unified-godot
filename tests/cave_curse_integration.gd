extends SceneTree
var cave: Node
func _initialize() -> void: call_deferred("run")
func open_cave() -> void:
	cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	assert(cave.walkthrough_ready)
	cave.set_process_unhandled_input(false)
func run() -> void:
	await open_cave()
	cave.curse.state.seed = 2
	var region: Dictionary = cave.curse.cave_regions[1]
	assert(int(region.region) == 1396)
	var center := Vector2.ZERO
	for v in region.polygon: center += Vector2(v[0],v[1])/region.polygon.size()
	# Source-region fixture; contact uses normal cave gravity and the live trigger.
	cave.player.global_position = cave.native_translation+Vector3(center.x,float(region.floor_min)+34,center.y)
	cave.player.velocity = Vector3.ZERO
	cave.flying = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in range(180):
		await physics_frame
		if cave.curse.state.cave_triggered: break
	assert(cave.curse.state.cave_triggered and cave.curse.state.phase == 1)
	cave.set_physics_process(false)
	cave.roach.model.player_health=7
	var path := "user://tests/curse_%d.json" % Time.get_ticks_usec()
	assert(cave._quicksave(path).is_empty())
	var saved: Dictionary = cave._save_state()
	cave.curse.advance(0.5)
	assert(cave._quickload(path).is_empty())
	assert(cave._save_state() == saved)
	# Pause/cursor release suspends production ticking without consuming RNG/time.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	cave.set_physics_process(true)
	cave.curse._physics_process(1.0)
	assert(cave._save_state() == saved)
	cave.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	cave.curse.advance(4.0)
	assert(cave.player_form == 2 and cave.curse.state.phase == 2)
	assert(cave.roach.model.player_health==30,"Morph did not heal actual cave health model")
	cave.roach.model.player_health=6
	assert(cave.player.get_child(0).shape.height == 8)
	assert(cave._quicksave(path).is_empty())
	saved = cave._save_state()
	await RenderingServer.frame_post_draw
	cave.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	await process_frame
	await open_cave()
	cave.set_physics_process(false)
	assert(cave._quickload(path).is_empty())
	assert(cave._save_state() == saved)
	assert(not cave.curse.request_cave_curse())
	set_meta("lol2_cave_completion",cave._completion_state())
	var expected: Dictionary = cave.curse.snapshot()
	await RenderingServer.frame_post_draw
	cave.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum)
	museum.set_physics_process(false)
	assert(museum.player_form == 2 and museum.curse.snapshot() == expected)
	assert(museum.quicksave(path).is_empty())
	var restored: Dictionary = museum.Save.read_save(path).state
	museum.curse.advance(1.0)
	museum.apply_save(restored)
	assert(museum.curse.snapshot() == expected)
	var inventory: Dictionary = museum.inventory_state()
	await RenderingServer.frame_post_draw
	museum.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	jungle.set_physics_process(false)
	assert(jungle.apply_inventory_handoff(inventory).is_empty())
	assert(jungle.curse.snapshot() == expected and jungle.player_form == 2)
	var handoff: Dictionary = jungle.area_handoff()
	await RenderingServer.frame_post_draw
	jungle.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	assert(hive.apply_area_handoff(handoff).is_empty())
	hive.set_physics_process(false)
	# Hive first arrival writes its documented initial admission (hive-curse.md: "Initial admission is
	# disabled") into the shared packet (admission_flags, added 2026-10-07); the rest travels unchanged.
	expected.admission_flags = 0
	assert(hive.curse.snapshot() == expected and hive.player_form == 2)
	assert(hive.get_node("Warriors").health==6,"Loading or area carry healed without a morph")
	assert(hive.quicksave(path).is_empty())
	hive.curse.advance(1.0)
	assert(hive.quickload(path).is_empty())
	assert(hive.curse.snapshot() == expected)
	await RenderingServer.frame_post_draw
	hive.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	DirAccess.remove_absolute(path)
	await process_frame
	await process_frame
	print("PASS source cave curse: grounded first-contact trigger, warning save rollback, pause, live lizard shape, fresh-scene/no-repeat, Museum/Jungle/Hive timer and disk carry")
	quit()
