extends "res://tests/l12_logs_approach_earned_test.gd"
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
	var path := "res://tmp/l16_centre_tower_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned centre tower save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned centre tower input"):
		await stop(scene, 1); return
	prepare(scene)
	var room = scene.get_node("L16DragonRoom")
	var ids_ok: bool = room.DRAGON == 241 and room.STATUE == 211 and room.DEST_LEVEL == 17 and room.DEST_SELECTOR == 1
	if not check(ids_ok, "dragon room ids"):
		await stop(scene, 1); return
	var hall_state: Variant = scene.quest_state.get("l16_centre_tower", {})
	var hall_ok: bool = hall_state is Dictionary and bool(hall_state.get("at_bars", false)) and bool(hall_state.get("seen_actor", false))
	if not check(hall_ok, "centre save keeps the hall record"):
		await stop(scene, 1); return
	scene.player.position = Vector3(281, 82, 10620)
	scene.player.velocity = Vector3.ZERO
	scene.camera.look_at(room.STATUE_AT, Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	await process_frame
	if not check(room.aimed(room.STATUE_AT, 180.0), "aimed at the statue"):
		await stop(scene, 1); return
	await click()
	if not check(not bool(room.state().chopped), "the statue click does not chop"):
		await stop(scene, 1); return
	scene.player.position = Vector3(1645, 82, 4435)
	scene.player.velocity = Vector3.ZERO
	scene.camera.look_at(room.DRAGON_AT, Vector3.UP)
	await process_frame
	await process_frame
	if not check(room.aimed(room.DRAGON_AT, 180.0), "aimed at prop 241"):
		await stop(scene, 1); return
	await click()
	if not check(bool(room.state().chopped), "the click chops the dragon"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	var before: int = scene.progression.level_changes.size()
	var off := Vector3(2100, 47, 4351)
	scene.player.position = off
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await process_frame
	var waiting: bool = not bool(room.state().pad_seen) and scene.progression.level_changes.size() == before
	waiting = waiting and room.flat_to(room.PAD) > 40.0
	if not check(waiting, "off the pad, no trip"):
		await stop(scene, 1); return
	var goal := Vector3(room.PAD.x, scene.player.position.y, room.PAD.z)
	var stepped := false
	for _tick in 240:
		var flat := Vector2(scene.player.position.x - goal.x, scene.player.position.z - goal.z)
		if flat.length() < 30.0:
			stepped = true
			break
		var step: Vector3 = goal - scene.player.position
		step.y = 0.0
		if step.length() < 0.01:
			break
		scene.move_grounded(step.normalized(), 1.0 / 60.0)
		await physics_frame
	await process_frame
	await process_frame
	var changes: Array = scene.progression.level_changes
	var requested: bool = stepped and changes.size() > before and int(changes[-1].level) == 17 and int(changes[-1].selector) == 1
	var pad_ok: bool = requested and bool(room.state().pad_seen) and scene.area_id == "L16_CA" and not room.relocates_player()
	if not check(pad_ok, "walk onto the pad requests L17 arrival 1 without E: %s %s" % [scene.player.position, changes]):
		await stop(scene, 1); return
	var trip: Dictionary = (changes[-1] as Dictionary).duplicate()
	var save := "res://tmp/l16_dragon_room_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "dragon save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "dragon reload"):
		await stop(scene, 1); return
	room = scene.get_node("L16DragonRoom")
	await process_frame
	var kept: bool = bool(room.state().chopped) and bool(room.state().pad_seen) and room.DOOR_ID == -1 and scene.area_id == "L16_CA"
	if not check(kept, "save keeps the chop on L16"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = true
	scene.progression._change_level(trip)
	await scene_changed
	scene = current_scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	prepare(scene)
	var arrived: bool = scene.area_id == "L17_HC" and int(scene.start_selector) == 1 and scene.arrived_by_level_change
	arrived = arrived and scene.player.position.distance_to(Vector3(1434, 32, -7075)) < 2.0
	if not check(arrived, "L17 arrival 1 without E: %s" % scene.player.position):
		await stop(scene, 1); return
	print("PASS earned centre save -> chop of prop 241 -> walk onto control 74 without E -> L17 arrival 1")
	await stop(scene, 0)
