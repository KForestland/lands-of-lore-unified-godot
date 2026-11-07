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
	var path := "res://tmp/l20_pillars_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned pillar save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L20_BB")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L20_BB.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned pillar input"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var arm = scene.get_node("L20Armory")
	var pillars = scene.get_node("L20PillarsScotia")
	if not check(pillars.state().shot.size() == 5 and bool(pillars.state().trinity), "pillar save still has the shots"):
		await stop(scene, 1); return
	scene.player.position = arm.AT_62
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 1
	scene.equipped_item = "act2:L13_RC:dark_sword"
	await process_frame
	await key(KEY_E)
	if not check(not bool(arm.state().hacked), "Beast form does not hack the block"):
		await stop(scene, 1); return
	scene.player_form = 0
	scene.equipped_item = ""
	await process_frame
	await key(KEY_E)
	if not check(not bool(arm.state().hacked), "an empty hand does not hack the block"):
		await stop(scene, 1); return
	scene.equipped_item = "act2:L13_RC:dark_sword"
	await process_frame
	await key(KEY_E)
	if not check(bool(arm.state().hacked) and arm.BRICK == -1 and not arm.stops_pillars(), "control 62 records a hack and the pillars stay moving"):
		await stop(scene, 1); return
	scene.player.position = arm.AT_67
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await key(KEY_E)
	scene.equipped_item = arm.BLUE_BOW
	scene.player.position = arm.AT_197
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await key(KEY_E)
	scene.player.position = arm.AT_196
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await key(KEY_E)
	var unbound: bool = not bool(arm.state().ball) and not bool(arm.state().fire) and not bool(arm.state().stopped) and arm.BALL == -1 and arm.FIREBALL == -1
	if not check(unbound, "the sources do not record a ball or a fireball"):
		await stop(scene, 1); return
	var save := "res://tmp/l20_armory_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "armory save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "armory reload"):
		await stop(scene, 1); return
	arm = scene.get_node("L20Armory")
	await process_frame
	if not check(bool(arm.state().hacked) and not bool(arm.state().ball), "save keeps the hack"):
		await stop(scene, 1); return
	print("PASS earned westernmost block")
	await stop(scene, 0)
