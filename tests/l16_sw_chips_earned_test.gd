extends "res://tests/l12_logs_approach_earned_test.gd"
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
	var path := "res://tmp/l16_nw_traps_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned NW trap save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned NW trap input"):
		await stop(scene, 1); return
	prepare(scene)
	var foyer = scene.get_node("L16SwChips")
	var doors_before: Array = travel_of(scene, foyer.DOORS)
	var ids_ok: bool = foyer.CHIP_IDS.size() == 5 and foyer.PYRAMID == 604 and "act2:L16_CA:item24" not in foyer.CHIP_IDS
	if not check(ids_ok, "pedestal chip list"):
		await stop(scene, 1); return
	var ne_state: Variant = scene.quest_state.get("l16_ne_tower", {})
	var oil_state: Variant = scene.quest_state.get("l16_se_oil", {})
	var nw_state: Variant = scene.quest_state.get("l16_nw_traps", {})
	var three: bool = ne_state is Dictionary and bool(ne_state.get("at_doors", false))
	three = three and oil_state is Dictionary and bool(oil_state.get("burned", false))
	three = three and nw_state is Dictionary and bool(nw_state.get("brick", false)) and bool(nw_state.get("fireball", false)) and bool(nw_state.get("ice", false))
	if not check(three, "NE door, SE burn, and NW breaks are in this save"):
		await stop(scene, 1); return
	scene.player.position = Vector3(-10089, 32, 12890)
	scene.player.velocity = Vector3.ZERO
	scene.camera.look_at(foyer.PEDESTALS[0], Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	await process_frame
	if not check(foyer.held_chip().is_empty(), "this save holds no ivory chip"):
		await stop(scene, 1); return
	if not check(foyer.aimed_index() == 0, "aimed at pedestal 173"):
		await stop(scene, 1); return
	await key(KEY_E)
	var empty: bool = foyer.state().placed.map(func(v): return int(v)) == [] and not foyer.chips[0].visible
	if not check(empty, "an empty hand leaves the pedestal clear"):
		await stop(scene, 1); return
	var row: Variant = scene.prop_placements.get(604)
	if not check(row is Array, "prop 604 placement"):
		await stop(scene, 1); return
	var whole: bool = (row[0] as MultiMesh).get_instance_transform(int(row[1])).basis.get_scale().length() > 0.5
	if not check(whole and travel_of(scene, foyer.DOORS) == doors_before, "the pyramid stays whole"):
		await stop(scene, 1); return
	var save := "res://tmp/l16_sw_chips_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "pedestal save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "pedestal reload"):
		await stop(scene, 1); return
	foyer = scene.get_node("L16SwChips")
	await process_frame
	var kept: bool = foyer.state().placed.map(func(v): return int(v)) == []
	if not check(kept, "save keeps the empty pedestals"):
		await stop(scene, 1); return
	print("PASS earned NW trap save -> SW pedestals stay clear, pyramid stays whole")
	await stop(scene, 0)

