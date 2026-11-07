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

func drain_ids(node: Node) -> Array:
	var out: Array = []
	for id in node.state().drain_switches:
		out.append(int(id))
	return out

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l19_sewer_forms_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned forms save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L19_BC")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L19_BC.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned forms input"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var route = scene.get_node("L19DrainPath")
	var forms = scene.get_node("L19SewerForms")
	if not check(forms.state().switches.size() == 3, "forms save still has the three slots"):
		await stop(scene, 1); return
	var planned: bool = route.WALK.size() == 3 and route.WALK[0][0] == 2557.0 and route.WALK[2][0] == 2621.5
	if not check(planned and not route.drain_required(), "open-movables 51 and 52 prefix"):
		await stop(scene, 1); return
	# Stand in front of the closed Golden Door, not inside it (DOOR_AT is movable 51's origin; Kimi K30 2026-11-07).
	scene.player.position = Vector3(2550, -68, -870)
	scene.player.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
	await key(KEY_E)
	for i in 30:
		await physics_frame
	if not check(bool(route.state().door_clicked) and drain_ids(route).is_empty() and route.moves_doors() and route.doors_open(), "the door click opens the Golden Doors and leaves the drain empty"):
		await stop(scene, 1); return
	if not await walk(scene, route.WALK, "short path to the region 1943 branch"):
		await stop(scene, 1); return
	if not check(drain_ids(route).is_empty(), "the short path does not require the drain"):
		await stop(scene, 1); return
	for point in [route.AT_50, route.AT_71, route.AT_72]:
		scene.player.position = point
		scene.player.velocity = Vector3.ZERO
		await process_frame
		await key(KEY_E)
	var got: Array = drain_ids(route)
	var drained: bool = got.size() == 3 and int(got[0]) == 50 and int(got[1]) == 71 and int(got[2]) == 72
	if not check(drained, "the three drain switches record after the walk"):
		await stop(scene, 1); return
	var save := "res://tmp/l19_drain_path_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "path save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "path reload"):
		await stop(scene, 1); return
	route = scene.get_node("L19DrainPath")
	await process_frame
	if not check(bool(route.state().door_clicked) and drain_ids(route).size() == 3, "save keeps the door and the drain"):
		await stop(scene, 1); return
	print("PASS earned optional drain and the short-path prefix")
	await stop(scene, 0)
