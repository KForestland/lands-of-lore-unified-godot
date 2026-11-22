extends "res://tests/l12_logs_approach_earned_test.gd"
func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func key(code: Key, shift: bool = false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.shift_pressed = shift
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await process_frame
	e = InputEventKey.new()
	e.keycode = code
	e.shift_pressed = shift
	e.pressed = false
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await process_frame

func shot_ids(node: Node) -> Array:
	var out: Array = []
	for id in node.state().shot:
		out.append(int(id))
	return out

func aim_lip(scene: Node, pillars: Node, id: int) -> void:
	scene.player.position = pillars.LIP
	scene.player.velocity = Vector3.ZERO
	scene.camera.global_position = pillars.LIP + Vector3(0, 24, 0)
	scene.camera.look_at(pillars.aim_point(id), Vector3.UP)

func click() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame

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
	# Explicit teaching fixture: old input predates the scroll/book contract.
	if not check(scene.starting_magic.learn_spell_group("prism"), "Legacy Prism teaching fixture"):
		await stop(scene,1); return
	await key(KEY_5)
	var pillars = scene.get_node("L20PillarsScotia")
	var mother = scene.get_node("L20MotherCurse")
	if not check(bool(mother.state().glob_entered), "mother save still has the glob"):
		await stop(scene, 1); return
	scene.player_form = 0
	scene.equipped_item = ""
	aim_lip(scene, pillars, 57)
	await physics_frame
	await click()
	var stayed_empty: bool = not pillars.shot_from_camera() and shot_ids(pillars).is_empty() and scene.player.position.distance_to(pillars.LIP) < 1.0
	if not check(stayed_empty, "an empty hand on the east lip does not record a pillar"):
		await stop(scene, 1); return
	scene.equipped_item = "act2:L13_RC:dark_sword"
	for id in pillars.FIRE:
		var body: Node = pillars.get_node("PillarShot%d" % int(id))
		if not check(body.has_meta("pillar_shot_receiver"), "pillar %d carries a shot receiver" % int(id)):
			await stop(scene, 1); return
		if int(id)==57:
			scene.player.position=pillars.AT_57
			await process_frame
			await key(KEY_E) # Existing west proximity action remains separate.
		else:
			aim_lip(scene, pillars, int(id))
			await physics_frame
			await click()
		if not check(int(id) in shot_ids(pillars), "pillar %d E57 / east lip click58-61" % int(id)):
			await stop(scene, 1); return
	var got: Array = shot_ids(pillars)
	var on_lip: bool = scene.player.position.distance_to(pillars.LIP) < 1.0
	var five: bool = on_lip and got.size() == 5 and int(got[0]) == 57 and int(got[4]) == 61 and pillars.opens_path() and not pillars.moves_pillars()
	if not check(five, "form 0 records the five fire pillars and the path opens before Trinity"):
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
	await key(KEY_Q,true)
	if not check(not bool(pillars.state().trinity), "Beast form does not record Trinity"):
		await stop(scene, 1); return
	scene.player_form = 0
	await process_frame
	await key(KEY_E)
	if not check(not bool(pillars.state().trinity), "E no longer performs Trinity"):
		await stop(scene,1); return
	await key(KEY_Q,true)
	var scotia: MeshInstance3D = pillars.get_node("ScotiaBody") as MeshInstance3D
	var opened: bool = bool(pillars.state().trinity) and pillars.TRINITY_LEVEL == 5 and pillars.PRISM == -1 and pillars.opens_path() and pillars.moves_pillars() and pillars.deck_ready() and not scotia.visible
	if not check(opened, "actor 48 records Trinity, Scotia falls, and the carrier starts"):
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
	if not check(shot_ids(pillars).size() == 5 and bool(pillars.state().trinity) and bool(pillars.state().path_open) and pillars.deck_ready(), "save keeps the shots and the open path"):
		await stop(scene, 1); return
	print("PASS legacy pillar component E57/click58-61 + actual Prism ShiftQ carrier/save; teaching/position/clock fixtures disclosed, not new earned walk")
	await stop(scene, 0)
