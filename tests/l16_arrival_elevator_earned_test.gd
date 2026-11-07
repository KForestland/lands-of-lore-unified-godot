extends "res://tests/l12_logs_approach_earned_test.gd"
## STORY-067: earned L16 arrival (from the Chamber of Voices test) -> walk into doorway region 233 -> native group 564
## movie 27 (ELEVATOR.VQA) -> decoded opcode 18 relocation to native (-3797,-2291) on the ground floor.
func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l16_arrival_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned L16 arrival save (run l14_chamber_voices_earned_test first)"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not check(scene.apply_save(input.state).is_empty(), "earned L16 arrival input"): quit(1); return
	prepare(scene)
	var lift = scene.get_node("L16ArrivalElevator")
	if not check(lift.assets_ready(), "original elevator movie staged"): quit(1); return
	var start: Vector3 = scene.player.position
	# The doorway panels are closed until Luther steps on the trigger plate.
	if not check(not lift.opened, "doorway closed on arrival"): quit(1); return
	if not await walk(scene, [[-3846, -1205]], "trigger plate"): quit(1); return
	for i in 120: scene.move_grounded(Vector3.ZERO, 1.0/60); await physics_frame
	if not check(lift.opened and lift.lift > lift.height, "plate retracts the doorway panels"): quit(1); return
	# Walk north through the doorway into region 233 with normal movement.
	var played := false
	for t in 2400:
		if is_instance_valid(lift.overlay): played = true; break
		var d: Vector3 = Vector3(-3870, 0, -1100) - scene.player.position; d.y = 0
		if d.length() < 4: break
		scene.move_grounded(d.normalized(), 1.0/60); await physics_frame
	if not played:
		for dy in [10.0, 40.0, 70.0]:
			var o: Vector3 = scene.player.global_position + Vector3(0, dy - 32.0, 0)
			var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + Vector3(0, 0, 80), 0xFFFFFFFF, [scene.player.get_rid()]))
			print("BLOCK dy ", dy, " ", hit.get("position"), " ", (hit.collider.get_path() if not hit.is_empty() else ""))
	if not check(played, "region 233 runs group 564 and the elevator movie starts (at %s, region %d)" % [scene.player.position, scene.progression.current_region]): quit(1); return
	if not check(paused, "world frozen during the movie"): quit(1); return
	var e := InputEventKey.new(); e.keycode = KEY_SPACE; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events()
	for i in 5: await process_frame
	if not check(not paused and lift.rides == 1, "Space skips the movie and the ride completes"): quit(1); return
	for i in 120: scene.move_grounded(Vector3.ZERO, 1.0/60); await physics_frame
	var p: Vector3 = scene.player.position
	if not check(Vector2(p.x, p.z).distance_to(Vector2(-3797, 2291)) < 4.0 and scene.player.is_on_floor() and absf(p.y - 32.0) < 6.0, "relocated to native (-3797,-2291) on the ground floor: %s" % p): quit(1); return
	if not check(scene.progression.region_at(p) == 343, "destination region 343 (got %d)" % scene.progression.region_at(p)): quit(1); return
	var error: String = scene._quicksave_unrecorded("res://tmp/l16_ground_earned_save.json")
	if not check(error.is_empty(), "ground save: " + error): quit(1); return
	check(scene._quickload_unrecorded("res://tmp/l16_ground_earned_save.json").is_empty() and Vector2(scene.player.position.x, scene.player.position.z).distance_to(Vector2(-3797, 2291)) < 4.0, "ground save reloads at the destination")
	check(scene.progression.seeds_applied.is_empty(), "no seeds")
	print("START ", start)
	scene.queue_free(); await process_frame
	if failures == 0: print("PASS earned L16 arrival -> walk into region 233 -> original ELEVATOR movie -> decoded relocation to the ground floor (region 343) -> save/reload")
	quit(1 if failures else 0)
