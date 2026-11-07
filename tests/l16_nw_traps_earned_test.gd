extends "res://tests/l12_logs_approach_earned_test.gd"
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

func travel_of(scene: Node, ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		out.append(int(scene.progression.travel.get(id, 0)))
	return out

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l16_se_oil_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned SE oil save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned SE oil input"):
		await stop(scene, 1); return
	prepare(scene)
	var traps = scene.get_node("L16NwTraps")
	var doors_before: Array = travel_of(scene, traps.DOORS)
	if not check(traps.BRICK == 88 and traps.FIRE == 89 and traps.ICE == 90, "trap props"):
		await stop(scene, 1); return
	var oil_state: Variant = scene.quest_state.get("l16_se_oil", {})
	var prior: bool = oil_state is Dictionary and bool(oil_state.get("burned", false)) and traps.BLUE in scene.carried_collected
	if not check(prior, "SE oil save keeps the burn and the blue bow"):
		await stop(scene, 1); return
	scene.player.position = Vector3(-10540, 132, -750)
	scene.player.velocity = Vector3.ZERO
	scene.hand_item = "act2:L13_RC:dark_sword"
	scene.camera.look_at(traps.BRICK_AT, Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	await process_frame
	await click()
	if not check(bool(traps.state().brick) and not bool(traps.state().fireball), "the brick breaks"):
		await stop(scene, 1); return
	scene.player.position = Vector3(-10400, 132, -1838)
	scene.player.velocity = Vector3.ZERO
	scene.camera.look_at(traps.FIRE_AT, Vector3.UP)
	await process_frame
	await process_frame
	await click()
	if not check(not bool(traps.state().fireball), "another weapon leaves the fireball"):
		await stop(scene, 1); return
	scene.hand_item = traps.BLUE
	await process_frame
	await click()
	var fired: bool = bool(traps.state().fireball) and traps.BLUE in scene.carried_collected
	if not check(fired, "the blue bow breaks the fireball and stays carried"):
		await stop(scene, 1); return
	scene.player.position = Vector3(-8900, 132, -3286)
	scene.player.velocity = Vector3.ZERO
	var receiver = traps.bodies[90].get_meta("spark_receiver")
	var low: bool = not receiver.receive_spark_level(1)
	var high: bool = receiver.receive_spark_level(3) and bool(traps.state().ice)
	if not check(low and high, "level-three spark breaks the white ball"):
		await stop(scene, 1); return
	if not check(travel_of(scene, traps.DOORS) == doors_before, "tower doors stay shut"):
		await stop(scene, 1); return
	var save := "res://tmp/l16_nw_traps_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "trap save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "trap reload"):
		await stop(scene, 1); return
	traps = scene.get_node("L16NwTraps")
	await process_frame
	var kept: bool = bool(traps.state().brick) and bool(traps.state().fireball) and bool(traps.state().ice)
	if not check(kept, "save keeps the three breaks"):
		await stop(scene, 1); return
	print("PASS earned SE oil save -> brick, blue bow, level-three spark")
	await stop(scene, 0)

