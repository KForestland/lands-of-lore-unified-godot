extends "res://tests/l12_logs_approach_earned_test.gd"
## STORY-070: earned L16 ground save -> walk to the NE greenhouse -> real E puts a silverleaf into the glass pyramid ->
## walk to the hourglass -> real E -> the fireball drifts to the tower -> FireWall Doors 92-94 open (native kind-10 group).
func key(code: Key) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	e = InputEventKey.new(); e.keycode = code; e.pressed = false
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l16_ground_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned L16 ground save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not check(scene.apply_save(input.state).is_empty(), "earned L16 ground input"): quit(1); return
	prepare(scene)
	var gh = scene.get_node("L16Greenhouse")
	var leaves: int = scene.carried_collected.filter(func(id): return gh.Items.definition(str(id)) == 117).size()
	if not check(leaves > 0, "earned save carries a silverleaf"): quit(1); return
	if not await walk(scene, JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l16_ground_to_greenhouse.json")), "streets to the greenhouse"): quit(1); return
	# Hourglass first: without a silverleaf it only chimes.
	if not await walk(scene, JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l16_greenhouse_to_hourglass.json")), "to the hourglass"): quit(1); return
	scene.camera.look_at(gh.HOURGLASS, Vector3.UP); await process_frame; await process_frame
	await key(KEY_E)
	if not check(float(gh.state().fireball) == 0.0, "hourglass without silverleaf only chimes"): quit(1); return
	var back: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l16_greenhouse_to_hourglass.json")); back.reverse(); back.append([2289, -490])
	if not await walk(scene, back.slice(1), "back to the pyramid"): quit(1); return
	scene.camera.look_at(gh.PLATE, Vector3.UP); await process_frame; await process_frame
	if not check(gh.hint.text.begins_with("E — Put a silverleaf"), "pyramid prompt: '%s'" % gh.hint.text): quit(1); return
	await key(KEY_E)
	var after: int = scene.carried_collected.filter(func(id): return gh.Items.definition(str(id)) == 117).size()
	if not check(not gh.state().silverleaf.is_empty() and after == leaves - 1, "real E consumes one silverleaf"): quit(1); return
	if not await walk(scene, JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l16_greenhouse_to_hourglass.json")), "to the hourglass again"): quit(1); return
	scene.camera.look_at(gh.HOURGLASS, Vector3.UP); await process_frame; await process_frame
	await key(KEY_E)
	if not check(float(gh.state().fireball) > 0.0, "hourglass starts the fireball"): quit(1); return
	for i in 2400:
		if gh.state().opened: break
		scene.move_grounded(Vector3.ZERO, 1.0/60); await physics_frame
	if not check(gh.state().opened, "fireball reaches the tower doors"): quit(1); return
	for i in 240: scene.move_grounded(Vector3.ZERO, 1.0/60); await physics_frame
	var pr = scene.progression
	var log: Array = pr.route_log.filter(func(r): return r.object == "prop:602" and int(r.event) == 10)
	print("KIND10 ", log)
	check(gh.DOORS.all(func(id): return pr.hinges.has(id) and int(pr.travel.get(id, 0)) == 100), "FireWall Doors 92-94 open: %s" % [gh.DOORS.map(func(id): return [pr.hinges.has(id), pr.travel.get(id)])])
	var error: String = scene._quicksave_unrecorded("res://tmp/l16_greenhouse_earned_save.json")
	if not check(error.is_empty(), "greenhouse save: " + error): quit(1); return
	check(scene._quickload_unrecorded("res://tmp/l16_greenhouse_earned_save.json").is_empty() and gh.state().opened, "save/reload keeps the open doors")
	# Probe: walk toward the tower and report where the body stops.
	for t in 2400:
		var d: Vector3 = Vector3(2290, 0, -3000) - scene.player.position; d.y = 0
		if d.length() < 8: break
		scene.move_grounded(d.normalized(), 1.0/60); await physics_frame
	print("TOWER PROBE ", scene.player.position, " region ", pr.region_at(scene.player.position))
	scene.queue_free(); await process_frame
	if failures == 0: print("PASS earned L16 ground -> greenhouse -> hourglass chimes alone -> real E silverleaf into the pyramid -> real E hourglass -> fireball -> FireWall Doors open -> save/reload")
	quit(1 if failures else 0)
