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
	var path := "res://tmp/l20_armory_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned armory save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L20_BB")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L20_BB.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned armory input"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var drar = scene.get_node("L20FauxDraracle")
	var arm = scene.get_node("L20Armory")
	if not check(bool(arm.state().hacked), "armory save still has the hack"):
		await stop(scene, 1); return
	scene.player.position = drar.AT_46
	scene.player.velocity = Vector3.ZERO
	scene.player_form = 1
	scene.equipped_item = "act2:L13_RC:dark_sword"
	await process_frame
	await key(KEY_E)
	if not check(not bool(drar.state().struck), "Beast form does not strike actor 46"):
		await stop(scene, 1); return
	scene.player_form = 0
	scene.equipped_item = ""
	await process_frame
	await key(KEY_E)
	if not check(not bool(drar.state().struck), "an empty hand does not strike actor 46"):
		await stop(scene, 1); return
	scene.equipped_item = "act2:L13_RC:dark_sword"
	await process_frame
	await key(KEY_E)
	var body: MeshInstance3D = drar.get_node("FauxBody") as MeshInstance3D
	if not check(bool(drar.state().struck) and bool(drar.state().killed) and not body.visible and drar.SPEECH == "Fight him any way you please.", "actor 46 falls and the line shows"):
		await stop(scene, 1); return
	scene.player.position = drar.AT_2
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await key(KEY_E)
	if not check(key_ids(drar).is_empty(), "key 2 before key 0 stays unrecorded"):
		await stop(scene, 1); return
	for point in [drar.AT_0, drar.AT_1, drar.AT_2]:
		scene.player.position = point
		scene.player.velocity = Vector3.ZERO
		await process_frame
		await key(KEY_E)
	var keys: Array = key_ids(drar)
	var leaf: MeshInstance3D = drar.get_node("DoorLeaf") as MeshInstance3D
	var ordered: bool = keys.size() == 3 and int(keys[0]) == 0 and int(keys[1]) == 1 and int(keys[2]) == 2 and bool(drar.state().room) and drar.moves_doors() and leaf.position.y > 1.0
	if not check(ordered, "keys 0, 1, and 2 open the door leaf"):
		await stop(scene, 1); return
	scene.player.position = drar.AT_75
	scene.player.velocity = Vector3.ZERO
	await process_frame
	await process_frame
	var card: Label = drar.find_child("Stage", true, false) as Label
	if not check(bool(drar.state().belial_seen) and drar.BELIAL == 75 and card != null and "Belial begins to speak." in card.text, "actor 75 is seen and Belial begins to speak"):
		await stop(scene, 1); return
	var save := "res://tmp/l20_faux_draracle_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "draracle save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "draracle reload"):
		await stop(scene, 1); return
	drar = scene.get_node("L20FauxDraracle")
	await process_frame
	body = drar.get_node("FauxBody") as MeshInstance3D
	leaf = drar.get_node("DoorLeaf") as MeshInstance3D
	if not check(bool(drar.state().room) and bool(drar.state().belial_seen) and bool(drar.state().killed) and not body.visible and leaf.position.y > 1.0, "save keeps the kill, the room, and the open leaf"):
		await stop(scene, 1); return
	print("PASS earned actor 46 falls, keys 0, 1, and 2, and the door leaf rises")
	await stop(scene, 0)
