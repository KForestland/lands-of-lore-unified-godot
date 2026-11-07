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

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l19_drain_path_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned path save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L19_BC")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L19_BC.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned path input"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var heads = scene.get_node("L19GhostlyHeads")
	var route = scene.get_node("L19DrainPath")
	if not check(bool(route.state().door_clicked), "path save still has the door click"):
		await stop(scene, 1); return
	scene.player.position = heads.AT_67
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 1
	await process_frame
	await key(KEY_E)
	if not check(shot_ids(heads).is_empty(), "Beast form does not record a head"):
		await stop(scene, 1); return
	scene.player_form = 0
	for point in [heads.AT_67, heads.AT_69, heads.AT_68, heads.AT_70]:
		scene.player.position = point
		scene.player.velocity = Vector3.ZERO
		await process_frame
		await key(KEY_E)
	var got: Array = shot_ids(heads)
	var four: bool = got.size() == 4 and int(got[0]) == 67 and int(got[1]) == 69 and int(got[2]) == 68 and int(got[3]) == 70
	if not check(four and heads.MIST_LEVEL == 1, "level-one shots record the four rectangle skulls"):
		await stop(scene, 1); return
	scene.player.position = heads.AT_66
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await key(KEY_E)
	if not check(shot_ids(heads).size() == 4 and not (heads.FIFTH in shot_ids(heads)), "prop 66 stays outside the four"):
		await stop(scene, 1); return
	scene.player.position = heads.IMP_AT
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await process_frame
	var open: bool = bool(heads.state().imp_seen) and heads.DEMON == -1 and heads.PLATE == -1 and heads.FOUNTAIN == -1 and heads.STONE == -1 and not bool(heads.state().dragged) and not heads.moves_player()
	if not check(open, "imp 31 is seen and the demon, plate, fountain, stone, and drag stay unbound"):
		await stop(scene, 1); return
	var save := "res://tmp/l19_ghostly_heads_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "heads save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "heads reload"):
		await stop(scene, 1); return
	heads = scene.get_node("L19GhostlyHeads")
	await process_frame
	if not check(shot_ids(heads).size() == 4 and bool(heads.state().imp_seen) and not bool(heads.state().dragged), "save keeps the four shots"):
		await stop(scene, 1); return
	print("PASS earned four ghostly heads from the short-path save")
	await stop(scene, 0)
