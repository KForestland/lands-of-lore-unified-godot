extends "res://tests/l12_logs_approach_earned_test.gd"
const LIP := [[2287.5, -1018.0], [2287.5, -1045.0], [2288.5, -1080.5], [2289.0, -1108.0], [2289.2, -1117.5]]
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
	var path := "res://tmp/l16_greenhouse_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned greenhouse save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned greenhouse input"):
		await stop(scene, 1); return
	prepare(scene)
	var tower = scene.get_node("L16NeTower")
	var module_ok: bool = tower.DOORS == [92, 93, 94] and tower.LIP_REGION == 6079 and tower.SECTIONS == 0 and tower.TOWER_RECORD == 615
	if not check(module_ok, "NE tower ids"):
		await stop(scene, 1); return
	var lip_ok: bool = LIP.size() == 5 and LIP[-1][0] == 2289.2 and LIP[-1][1] == -1117.5
	if not check(lip_ok, "hourglass lip route"):
		await stop(scene, 1); return
	if not await walk(scene, LIP, "greenhouse save to region 6079"):
		await stop(scene, 1); return
	scene.player.position = Vector3(2292, 32, -2950)
	scene.player.velocity = Vector3.ZERO
	# The door point is directly above this spot. Looking at it pitches past the save's view limit.
	scene.camera.look_at(tower.DOOR + Vector3(0, -8, -40), Vector3.UP)
	await process_frame
	await process_frame
	var at_door: bool = bool(tower.state().at_doors) and tower.hint.text == "The disk and the box are not placed. The centre stays down."
	if not check(at_door, "door quad records the entrance: '%s'" % tower.hint.text):
		await stop(scene, 1); return
	var stayed: bool = not tower.relocates_player() and scene.player.position.distance_to(tower.ARRIVAL) > 1000.0
	if not check(stayed, "Luther stays on the door quad"):
		await stop(scene, 1); return
	var row: Variant = scene.prop_placements.get(615)
	if not check(row is Array, "prop 615 placement"):
		await stop(scene, 1); return
	var standing: bool = (row[0] as MultiMesh).get_instance_transform(int(row[1])).basis.get_scale().length() > 0.5
	if not check(standing, "centre tower mesh stays up"):
		await stop(scene, 1); return
	var save := "res://tmp/l16_ne_tower_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "NE tower save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "NE tower reload"):
		await stop(scene, 1); return
	tower = scene.get_node("L16NeTower")
	await process_frame
	var kept: bool = bool(tower.state().at_doors) and tower.SECTIONS == 0
	if not check(kept, "save keeps the door record"):
		await stop(scene, 1); return
	print("PASS earned greenhouse -> region 6079 -> door quad, centre stays down")
	await stop(scene, 0)

