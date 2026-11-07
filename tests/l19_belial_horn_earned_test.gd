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
	var path := "res://tmp/l19_beast_wall_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned beast-wall save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L19_BC")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L19_BC.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned beast-wall input"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var horn = scene.get_node("L19BelialHorn")
	var wall = scene.get_node("L19BeastWall")
	if not check(bool(wall.state().noted) and wall.MOVIE == -1, "T04 gap stays on the loaded save"):
		await stop(scene, 1); return
	scene.player.position = horn.PIPE_AT
	scene.player.velocity = Vector3.ZERO
	await process_frame
	if not check(not bool(horn.state().taken) and not horn.death_stored(), "the horn starts untaken"):
		await stop(scene, 1); return
	await key(KEY_E)
	var carried: bool = bool(horn.state().taken) and horn.ITEM in scene.carried_collected and horn.ITEM in scene.quest_state.act2_items.collected
	if not check(carried, "E grants act2:L19_BC:horn"):
		await stop(scene, 1); return
	if not check(horn.ACTOR_REGION != horn.PIPE_REGION, "actor 32 stays off the pipe"):
		await stop(scene, 1); return
	var save := "res://tmp/l19_belial_horn_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "horn save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "horn reload"):
		await stop(scene, 1); return
	horn = scene.get_node("L19BelialHorn")
	await process_frame
	if not check(bool(horn.state().taken) and horn.ITEM in scene.carried_collected, "save keeps the horn"):
		await stop(scene, 1); return
	print("PASS earned Belial's Horn from the beast-wall save")
	await stop(scene, 0)
