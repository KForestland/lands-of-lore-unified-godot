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
	var path := "res://tmp/l16_ne_tower_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned NE tower save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned NE tower input"):
		await stop(scene, 1); return
	prepare(scene)
	var oil = scene.get_node("L16SeOil")
	var doors_before: Array = travel_of(scene, oil.DOORS)
	if not check(oil.FOUNTAIN_RECORD == 392 and oil.BOW == "act2:L16_CA:item24", "oil ids"):
		await stop(scene, 1); return
	var ne_state: Variant = scene.quest_state.get("l16_ne_tower", {})
	if not check(ne_state is Dictionary and bool(ne_state.get("at_doors", false)), "NE tower save keeps the door record"):
		await stop(scene, 1); return
	scene.player.position = Vector3(-2188, 27, 12870)
	scene.player.velocity = Vector3.ZERO
	scene.camera.look_at(oil.FOUNTAIN, Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	await process_frame
	if not check(oil.aimed(oil.FOUNTAIN, 180.0), "aimed at prop 392"):
		await stop(scene, 1); return
	await click()
	if not check(bool(oil.state().burned) and oil.flame.visible, "the oil catches"):
		await stop(scene, 1); return
	var doors_after: Array = travel_of(scene, oil.DOORS)
	if not check(doors_after == doors_before, "fire doors stay"):
		await stop(scene, 1); return
	scene.player.position = Vector3(-2500, 27, 12858)
	scene.player.velocity = Vector3.ZERO
	var items = scene.get_node("Act2WorldItems")
	scene.camera.look_at(items.aim_point(oil.BOW), Vector3.UP)
	await process_frame
	await process_frame
	await key(KEY_E)
	var took: bool = oil.BOW in scene.carried_collected and oil.BLUE in scene.carried_collected
	if not check(took, "Dark Bow taken and the blue bow stays"):
		await stop(scene, 1); return
	var save := "res://tmp/l16_se_oil_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "oil save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "oil reload"):
		await stop(scene, 1); return
	oil = scene.get_node("L16SeOil")
	await process_frame
	var collected: Array = scene.quest_state.act2_items.collected.map(func(v): return str(v))
	var kept: bool = bool(oil.state().burned) and oil.BOW in collected and oil.BLUE in scene.carried_collected
	if not check(kept, "save keeps the burn and both bows"):
		await stop(scene, 1); return
	print("PASS earned NE tower save -> prop 392 burns -> Dark Bow taken, blue bow stays")
	await stop(scene, 0)

