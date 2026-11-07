extends "res://tests/l12_logs_approach_earned_test.gd"
## STORY-068: earned L16 ground save -> avenue route from build_nav_walk.py -> pad click breaks prop 210.
## Region 9806 is bit0, so the tool route ends on region 9732. The click stands on the pad.
func key(code: Key) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	e = InputEventKey.new(); e.keycode = code; e.pressed = false
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame

func click() -> void:
	var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame
	e = InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = false
	Input.parse_input_event(e); Input.flush_buffered_events(); await process_frame

func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

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
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned L16 ground input"):
		await stop(scene, 1); return
	prepare(scene)
	var fountain = scene.get_node("L16DryFountain")
	var module_ok: bool = fountain.BALL_RECORD == 210 and fountain.KEY == "l16_dry_fountain"
	if not check(module_ok, "prop 210 module"):
		await stop(scene, 1); return
	var route = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l16_ground_to_south_avenue.json"))
	var route_ok: bool = route is Array and route.size() == 88 and route[-1][0] == 459.5 and route[-1][1] == 9755.0
	if not check(route_ok, "avenue route"):
		await stop(scene, 1); return
	if not await walk(scene, route, "ground save to the south avenue"):
		await stop(scene, 1); return
	print("AVENUE ", scene.player.position)
	# Floor 50, body origin 82. This stands inside region 9806 and clear of the orb.
	scene.player.position = Vector3(438, 82, 10390)
	scene.player.velocity = Vector3.ZERO
	scene.camera.look_at(fountain.ORB, Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	await process_frame
	if not check(fountain.aimed(fountain.ORB, 200.0), "aimed at prop 210"):
		await stop(scene, 1); return
	if not check(fountain.hint.text == "Left click — Strike the floating ball", "orb prompt: '%s'" % fountain.hint.text):
		await stop(scene, 1); return
	await click()
	var broke: bool = fountain.state().broken and fountain.state().water
	if not check(broke, "the click breaks the orb"):
		await stop(scene, 1); return
	if not check(fountain.water.visible, "water shows"):
		await stop(scene, 1); return
	var shown := 0
	for clump in fountain.clumps:
		if clump.visible: shown += 1
	if not check(shown == 9, "nine clumps"):
		await stop(scene, 1); return
	var row: Variant = scene.prop_placements.get(210)
	if not check(row is Array, "prop 210 placement"):
		await stop(scene, 1); return
	var hidden: bool = (row[0] as MultiMesh).get_instance_transform(int(row[1])).basis.get_scale().length() < 0.01
	if not check(hidden, "orb billboard hidden"):
		await stop(scene, 1); return
	scene.camera.look_at(fountain.LICHEN_AT[0] + Vector3.UP * 6, Vector3.UP)
	await process_frame
	await process_frame
	await key(KEY_E)
	if not check(fountain.state().taken == [0], "one clump taken"):
		await stop(scene, 1); return
	if not check(fountain.clump_id(0) in scene.carried_collected, "black lichen carried"):
		await stop(scene, 1); return
	var save := "res://tmp/l16_dry_fountain_earned_save.json"
	var error: String = scene._quicksave_unrecorded(save)
	if not check(error.is_empty(), "fountain save: " + error):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "fountain reload"):
		await stop(scene, 1); return
	fountain = scene.get_node("L16DryFountain")
	await process_frame
	var kept: bool = fountain.state().broken and fountain.state().taken.map(func(v): return int(v)) == [0]
	if not check(kept, "save keeps the break"):
		await stop(scene, 1); return
	print("PASS earned L16 ground -> south avenue -> prop 210 breaks -> water -> one black lichen -> save/reload")
	await stop(scene, 0)
