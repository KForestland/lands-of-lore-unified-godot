extends "res://tests/l12_logs_approach_earned_test.gd"
func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await process_frame
	e = InputEventKey.new()
	e.keycode = code
	e.pressed = false
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await process_frame

func shot_ids(node: Node) -> Array:
	var out: Array = []
	for id in node.state().shot:
		out.append(int(id))
	return out

func key_ids(node: Node) -> Array:
	var out: Array = []
	for id in node.state().keys:
		out.append(int(id))
	return out

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l20_dawn_curse_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned mother save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L20_BB")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L20_BB.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned mother input"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var pillars = scene.get_node("L20PillarsScotia")
	var mother = scene.get_node("L20MotherCurse")
	if not check(bool(mother.state().glob_entered), "mother save still has the glob"):
		await stop(scene, 1); return
	scene.player.position = pillars.AT_57
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 0
	scene.equipped_item = ""
	await process_frame
	await key(KEY_E)
	if not check(shot_ids(pillars).is_empty(), "an empty hand does not record a pillar"):
		await stop(scene, 1); return
	scene.equipped_item = "act2:L13_RC:dark_sword"
	for point in [pillars.AT_57, pillars.AT_58, pillars.AT_59, pillars.AT_60, pillars.AT_61]:
		scene.player.position = point
		scene.player.velocity = Vector3.ZERO
		await process_frame
		await key(KEY_E)
	var got: Array = shot_ids(pillars)
	var five: bool = got.size() == 5 and int(got[0]) == 57 and int(got[4]) == 61 and not pillars.opens_path()
	if not check(five, "form 0 records the five fire pillars and the path stays closed"):
		await stop(scene, 1); return
	scene.player.position = pillars.AT_62
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await key(KEY_E)
	if not check(shot_ids(pillars).size() == 5 and not (pillars.ICE in shot_ids(pillars)), "ice pillar 62 stays outside the row"):
		await stop(scene, 1); return
	scene.player.position = pillars.SCOTIA_AT
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 1
	await process_frame
	await key(KEY_E)
	if not check(not bool(pillars.state().trinity), "Beast form does not record Trinity"):
		await stop(scene, 1); return
	scene.player_form = 0
	await process_frame
	await key(KEY_E)
	if not check(bool(pillars.state().trinity) and pillars.TRINITY_LEVEL == 5 and pillars.PRISM == -1 and not pillars.moves_pillars(), "actor 48 records Trinity and the pillars stay still"):
		await stop(scene, 1); return
	var before: Vector3 = pillars.STAIR_AT
	scene.player.position = before
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await key(KEY_E)
	if not check(scene.player.position.distance_to(before) < 0.1 and not pillars.relocates_player(), "the level-change band does not move Luther"):
		await stop(scene, 1); return
	var save := "res://tmp/l20_pillars_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "pillar save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "pillar reload"):
		await stop(scene, 1); return
	pillars = scene.get_node("L20PillarsScotia")
	await process_frame
	if not check(shot_ids(pillars).size() == 5 and bool(pillars.state().trinity) and not bool(pillars.state().path_open), "save keeps the shots and the closed path"):
		await stop(scene, 1); return
	print("PASS earned fire pillars and actor 48")
	await stop(scene, 0)
