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

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l17_cavern_run_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned cavern save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L17_HC")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L17_HC.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned cavern input"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var blade = scene.get_node("L17BeastBlade")
	var run = scene.get_node("L17CavernRun")
	if not check(int(run.state().exit_region) == 1312, "cavern save still records region 1312"):
		await stop(scene, 1); return
	scene.player.position = blade.WEST_AT
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 0
	scene.equipped_item = ""
	await process_frame
	await key(KEY_E)
	if not check(not bool(blade.state().cut), "an empty hand does not cut"):
		await stop(scene, 1); return
	scene.player_form = 2
	scene.equipped_item = "act2:L13_RC:dark_sword"
	await key(KEY_E)
	if not check(not bool(blade.state().cut), "Lizard form does not cut"):
		await stop(scene, 1); return
	scene.player_form = 0
	var before: Vector3 = scene.player.position
	await key(KEY_E)
	var cut: bool = bool(blade.state().cut) and blade.SCENE_NAME == "hw01.vqa" and not blade.plays_movie()
	if not check(cut, "Human with a blade records hw01.vqa and does not play it"):
		await stop(scene, 1); return
	if not check(scene.player.position.distance_to(before) < 1.0 and not blade.relocates_player(), "Luther stays on the west edge"):
		await stop(scene, 1); return
	var save := "res://tmp/l17_beast_blade_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "blade save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "blade reload"):
		await stop(scene, 1); return
	blade = scene.get_node("L17BeastBlade")
	await process_frame
	if not check(bool(blade.state().cut) and blade.STRAND_ID == -1, "save keeps the cut and the unbound strand"):
		await stop(scene, 1); return
	print("PASS earned west-wall blade records hw01.vqa from the cavern save")
	await stop(scene, 0)
