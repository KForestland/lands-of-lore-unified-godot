extends "res://tests/l12_logs_approach_earned_test.gd"
## BJ09: the dry-fountain sitting's own save -> walk back along the west ledge -> streets to the
## greenhouse -> the same silverleaf and hourglass the ground-save test already does. No placement.
func key(code: Key) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	e = InputEventKey.new(); e.keycode = code; e.pressed = false
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l16_dry_fountain_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned dry fountain save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not check(scene.apply_save(input.state).is_empty(), "earned dry fountain input"): quit(1); return
	prepare(scene)
	var gh = scene.get_node("L16Greenhouse")
	var fountain = scene.get_node("L16DryFountain")
	if not check(fountain.state().broken and fountain.state().taken.map(func(v): return int(v)) == [0], "fountain sitting is already broken"): quit(1); return
	var leaves: int = scene.carried_collected.filter(func(id): return gh.Items.definition(str(id)) == 117).size()
	if not check(leaves > 0, "fountain save still carries a silverleaf"): quit(1); return
	var back_ledge: Array = [[180, 10435], [50, 10435], [20, 10435], [-115, 10350], [-115, 10295], [-115, 10250], [-115, 9930], [-65.5, 9871.5], [7.5, 9849.5], [20, 9755], [230, 9755], [459.5, 9755]]
	if not await walk(scene, back_ledge, "ledge back to the avenue"): quit(1); return
	if not await walk(scene, JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l16_avenue_to_greenhouse.json")), "avenue to the greenhouse"): quit(1); return
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
		if not await fight_nearby(scene): quit(1); return
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0); await physics_frame
	if not check(gh.state().opened, "fireball reaches the tower doors"): quit(1); return
	for i in 240:
		if not await fight_nearby(scene): quit(1); return
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0); await physics_frame
	var pr = scene.progression
	check(gh.DOORS.all(func(id): return pr.hinges.has(id) and int(pr.travel.get(id, 0)) == 100), "FireWall Doors 92-94 open: %s" % [gh.DOORS.map(func(id): return [pr.hinges.has(id), pr.travel.get(id)])])
	var error: String = scene._quicksave_unrecorded("res://tmp/l16_greenhouse_chain_earned_save.json")
	if not check(error.is_empty(), "greenhouse chain save: " + error): quit(1); return
	check(scene._quickload_unrecorded("res://tmp/l16_greenhouse_chain_earned_save.json").is_empty() and gh.state().opened, "save/reload keeps the open doors")
	print("GREENHOUSE ", scene.player.position, " region ", scene.progression.region_at(scene.player.position))
	scene.queue_free(); await process_frame
	if failures == 0: print("PASS earned dry fountain -> west ledge back -> streets -> greenhouse silverleaf -> hourglass -> FireWall doors open -> save/reload")
	quit(1 if failures else 0)
