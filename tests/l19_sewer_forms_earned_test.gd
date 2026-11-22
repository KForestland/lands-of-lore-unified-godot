extends "res://tests/l12_logs_approach_earned_test.gd"
func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func ids_of(node: Node) -> Array:
	var out: Array = []
	for id in node.state().switches:
		out.append(int(id))
	return out

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

func press_g() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_G
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l19_belial_horn_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned horn save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L19_BC")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L19_BC.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned horn input"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	var forms = scene.get_node("L19SewerForms")
	var horn = scene.get_node("L19BelialHorn")
	if not check(bool(horn.state().taken), "horn save still carries the horn"):
		await stop(scene, 1); return
	scene.player.position = Vector3(-320.0, -8.0, -1760.0)
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 0
	scene.camera.global_position = scene.player.global_position + Vector3(0, 8, 0)
	scene.camera.look_at(Vector3(-344.0, -20.0, -1667.0), Vector3.UP)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var before: Vector3 = scene.player.position
	await click()
	var rose := false
	for _step in 500:
		scene.progression.advance_floors(1.0 / 60.0)
		await physics_frame
		if int(scene.progression.regions[40][1]) == -20:
			rose = true
			break
	var leaf: MeshInstance3D = forms.get_node("BarLeaf") as MeshInstance3D
	var stayed: bool = Vector2(scene.player.position.x, scene.player.position.z).distance_to(Vector2(before.x, before.z)) < 1.0
	var lifted: bool = rose and absf(scene.player.position.y - 12.0) < 1.0 and leaf.position.y > forms.DOOR_AT.y + 1.0
	if not check(lifted and stayed and not forms.moves_door() and forms.BARS == -1, "Human strike raises region 40 and Luther rises with it: %s" % scene.player.position):
		await stop(scene, 1); return
	await press_g()
	if not check(bool(forms.state().lizard_at_wall) and ids_of(forms).is_empty() and forms.GUTTER == -1, "G at the gutter mouth asks for the Lizard"):
		await stop(scene, 1); return
	for _i in 400:
		scene.curse.advance(1.0 / 60.0)
		await physics_frame
		if scene.player_form == 2:
			break
	if not check(scene.player_form == 2, "the gutter mouth finishes as the Lizard"):
		await stop(scene, 1); return
	await press_g()
	for _back in 30:
		scene.curse.advance(1.0 / 60.0)
		await physics_frame
		if scene.player_form == 0 and int(scene.curse.state.phase) == 0:
			break
	if not check(scene.player_form == 0 and int(scene.curse.state.phase) == 0, "G returns to Human before the slots"):
		await stop(scene, 1); return
	var channel_before: int = int(scene.progression.regions[103][1])
	scene.player.position = Vector3(forms.AIM_75.x, 22.0, -2088.0)
	scene.player.velocity = Vector3.ZERO
	scene.camera.global_position = scene.player.global_position + Vector3(0, 8, 0)
	scene.camera.look_at(forms.AIM_75, Vector3.UP)
	await click()
	if not check(ids_of(forms).is_empty() and int(scene.progression.regions[103][1]) == channel_before, "the equipped sword does not shoot a slot"):
		await stop(scene, 1); return
	scene.player_form = 1
	if not check(scene.set_equipped_item(forms.BLUE_BOW), "the carried blue bow equips"):
		await stop(scene, 1); return
	scene.camera.look_at(forms.AIM_75, Vector3.UP)
	await click()
	if not check(ids_of(forms).is_empty(), "Beast form does not shoot a slot"):
		await stop(scene, 1); return
	scene.player_form = 0
	var aims: Array = [forms.AIM_74, forms.AIM_75, forms.AIM_76]
	for raw in aims:
		var point: Vector3 = raw
		scene.player.position = Vector3(point.x, 22.0, -2088.0)
		scene.player.velocity = Vector3.ZERO
		scene.camera.global_position = scene.player.global_position + Vector3(0, 8, 0)
		scene.camera.look_at(point, Vector3.UP)
		await click()
	var flooded := false
	for _step in 500:
		scene.progression.advance_floors(1.0 / 60.0)
		await physics_frame
		if int(scene.progression.regions[103][1]) == -45:
			flooded = true
			break
	var got: Array = ids_of(forms)
	var angle: int = int(scene.progression.native.attributes["movable:77"].angle_word)
	var slots: bool = got.size() == 3 and int(got[0]) == 74 and int(got[1]) == 75 and int(got[2]) == 76
	if not check(slots and flooded and int(scene.progression.travel.get(77, -1)) == angle, "Human bow shots record switches 74, 75, and 76 and raise region 103"):
		await stop(scene, 1); return
	var save := "res://tmp/l19_sewer_forms_earned_save.json"
	var saved := str(scene._quicksave_unrecorded(save))
	if not check(saved.is_empty(), "forms save " + saved):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "forms reload"):
		await stop(scene, 1); return
	forms = scene.get_node("L19SewerForms")
	await process_frame
	var kept: bool = ids_of(forms).size() == 3 and bool(forms.state().lizard_at_wall) and int(forms.state().get("counter", -1)) == 3 and int(scene.progression.native.locals.get(0, -1)) == 3
	if not check(kept, "save keeps the form checks and local 0"):
		await stop(scene, 1); return
	print("PASS earned sewer bars, the gutter, and switches 74, 75, and 76")
	await stop(scene, 0)
