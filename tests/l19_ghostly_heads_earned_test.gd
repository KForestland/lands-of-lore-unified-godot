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
	# Explicit legacy component teaching fixture; old checkpoint predates scroll use.
	if not check(scene.starting_magic.learn_spell_group("mists"), "Legacy Mists teaching fixture"):
		await stop(scene, 1); return
	await key(KEY_4)
	var heads = scene.get_node("L19GhostlyHeads")
	var route = scene.get_node("L19DrainPath")
	if not check(bool(route.state().door_clicked), "path save still has the door click"):
		await stop(scene, 1); return
	scene.player.position = heads.AT_67
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 1
	await process_frame
	await key(KEY_Q)
	if not check(shot_ids(heads).is_empty(), "Beast form does not record a head"):
		await stop(scene, 1); return
	scene.player_form = 0
	for point in [heads.AT_67, heads.AT_69, heads.AT_68, heads.AT_70]:
		scene.player.position = point
		scene.player.velocity = Vector3.ZERO
		await process_frame
		await key(KEY_Q)
		await create_timer(0.6).timeout # Ordinary caster cooldown under the disclosed 4/240 harness.
	var got: Array = shot_ids(heads)
	var four: bool = got.size() == 4 and int(got[0]) == 67 and int(got[1]) == 69 and int(got[2]) == 68 and int(got[3]) == 70
	if not check(four and heads.MIST_LEVEL == 1, "level-one shots record the four rectangle skulls"):
		await stop(scene, 1); return
	scene.player.position = heads.AT_66
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await key(KEY_Q)
	if not check(shot_ids(heads).size() == 4 and not (heads.FIFTH in shot_ids(heads)), "prop 66 stays outside the four"):
		await stop(scene, 1); return
	scene.player.position = heads.IMP_AT
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await process_frame
	var token: MeshInstance3D = heads.get_node("SkullToken") as MeshInstance3D
	var open: bool = bool(heads.state().imp_seen) and heads.DEMON == -1 and heads.PLATE == -1 and heads.FOUNTAIN == -1 and heads.STONE == -1 and bool(heads.state().dragged) and not heads.moves_player() and token.position.distance_to(heads.CIRCLE_AT) < 0.1 and heads.get_node("WhiteCircle").visible and heads.get_node("RedFountain").visible
	if not check(open, "imp 31 is seen and the token sits on the white circle"):
		await stop(scene, 1); return
	# The save is the next leg's fixture (l19_dawn_curse_earned_test): let every moving floor settle first, so it is a
	# stable state and not a ride in progress (lead 2026-11-14; the cab descends from arrival, local 4 = 1).
	var pr: Node = scene.progression
	for _settle in 2000:
		var moving := false
		for raw in pr.floor_motion: if int((pr.floor_motion[raw] as Dictionary).remaining) != 0: moving = true
		if not moving: break
		pr.advance_floors(8.0 / 60.0)
		await process_frame
	var still := true
	for raw in pr.floor_motion: if int((pr.floor_motion[raw] as Dictionary).remaining) != 0: still = false
	if not check(still, "every moving floor settles before the heads save (cab %s)" % [str(pr.floor_motion.get(1943, {}))]):
		await stop(scene, 1); return
	var save := "res://tmp/l19_ghostly_heads_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "heads save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "heads reload"):
		await stop(scene, 1); return
	heads = scene.get_node("L19GhostlyHeads")
	await process_frame
	token = heads.get_node("SkullToken") as MeshInstance3D
	if not check(shot_ids(heads).size() == 4 and bool(heads.state().imp_seen) and bool(heads.state().dragged) and token.position.distance_to(heads.CIRCLE_AT) < 0.1, "save keeps the four shots and the token"):
		await stop(scene, 1); return
	print("PASS legacy heads component: real Mists Q with disclosed teaching/position/clock aids, four shots and token save; not new earned walk")
	await stop(scene, 0)
