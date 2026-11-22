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
	var path := "res://tmp/l20_faux_draracle_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned draracle save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L20_BB")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene: Node = load("res://scenes/lol2/maps/L20_BB.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned draracle input"):
		await stop(scene, 1); return
	scene.progression.change_scene_enabled = false
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var end = scene.get_node("L20Finale")
	var drar = scene.get_node("L20FauxDraracle")
	if not check(bool(drar.state().room) and bool(drar.state().belial_seen), "draracle save still has the room"):
		await stop(scene, 1); return
	var chain_weapon := ""
	if "act2:L19_BC:horn" in scene.carried_collected or str(scene.equipped_item) == "act2:L19_BC:horn":
		chain_weapon = "act2:L19_BC:horn"
	elif "act2:L13_RC:dark_sword" in scene.carried_collected or str(scene.equipped_item) == "act2:L13_RC:dark_sword":
		chain_weapon = "act2:L13_RC:dark_sword"
	elif "act2:L12_CM:blue_bow" in scene.carried_collected or str(scene.equipped_item) == "act2:L12_CM:blue_bow":
		chain_weapon = "act2:L12_CM:blue_bow"
	if not check(chain_weapon != "", "the chain carries the horn, the Dark Sword, or the blue bow"):
		await stop(scene, 1); return
	scene.player_form = 0
	var physics: bool = scene.is_physics_processing()
	scene.set_physics_process(false)
	var approaches: Array[Vector3] = [Vector3(40, 6, 0), Vector3(-40, 6, 0), Vector3(0, 6, -40), Vector3(0, 6, 40)]
	for start in approaches:
		scene.player.position = end.AT_75 + start
		scene.player.velocity = Vector3.ZERO
		var stuck: int = 0
		var previous: Vector3 = scene.player.position
		for _tick in 300:
			if end.flat_to(end.AT_75) < end.REACH - 1.0:
				break
			var step_to: Vector3 = end.AT_75 - scene.player.position
			step_to.y = 0.0
			if step_to.length() < 0.01:
				break
			scene.move_grounded(step_to.normalized(), 1.0 / 60.0)
			await physics_frame
			var moved: float = Vector2(scene.player.position.x - previous.x, scene.player.position.z - previous.z).length()
			previous = scene.player.position
			stuck = stuck + 1 if moved < 0.05 else 0
			if stuck >= 20:
				break
		if end.flat_to(end.AT_75) < end.REACH:
			break
	scene.set_physics_process(false)
	if not check(end.flat_to(end.AT_75) < end.REACH, "walked to Belial at %s" % scene.player.position):
		await stop(scene, 1); return
	# Empty the hand the way the inventory does: the held item goes back into the pack (a save needs the equipped item in
	# the carried list), so the chain weapon is still owned when it is held again below.
	if str(scene.equipped_item) != "" and not str(scene.equipped_item) in scene.carried_collected:
		var pack: Array = scene.carried_collected.duplicate()
		pack.append(str(scene.equipped_item))
		scene.carried_collected = pack
	scene.equipped_item = ""
	await process_frame
	await key(KEY_E)
	if not check(not bool(end.state().started), "an empty hand does not start the fight"):
		await stop(scene, 1); return
	scene.equipped_item = "act2:L16_CA:item24"
	await process_frame
	await key(KEY_E)
	if not check(not bool(end.state().started), "the Dark Bow does not start this fight"):
		await stop(scene, 1); return
	var before: Vector3 = scene.player.position
	scene.equipped_item = chain_weapon
	await process_frame
	await key(KEY_E)
	var started: bool = bool(end.state().started) and str(end.state().weapon) == chain_weapon and scene.player.position.distance_to(before) < 0.1 and not end.moves_player()
	if not check(started, "the carried weapon starts the same flag and Luther stays"):
		await stop(scene, 1); return
	var card: Label = end.find_child("Stage", true, false) as Label
	var saw_chasm := false
	var saw_vow := false
	var saw_slump := false
	var saw_dawn := false
	var saw_draracle := false
	var saw_vanish := false
	var shown := false
	for _i in 500:
		await process_frame
		card = end.find_child("Stage", true, false) as Label
		var line: String = "" if card == null else card.text
		if "across a chasm" in line: saw_chasm = true
		if "never to return" in line: saw_vow = true
		if "slumps" in line: saw_slump = true
		if "with Dawn" in line: saw_dawn = true
		if "drops in" in line: saw_draracle = true
		if "vanishes" in line: saw_vanish = true
		var now: Dictionary = end.state()
		var credit: Label = end.get_node_or_null("Credits/CreditLine") as Label
		shown = saw_chasm and saw_vow and saw_slump and saw_dawn and saw_draracle and saw_vanish and card != null and "The game is finished." in line and end.plays_movie() and end.finished(now) and bool(now.game_finished) and end.get_node("Chasm").visible and credit != null and end.get_node("Credits").visible and credit.text == "The End" and scene.player.position.distance_to(before) < 0.1
		if shown:
			break
	if not check(shown, "the paced beats, the chasm prop, and the credits finish the game"):
		await stop(scene, 1); return
	var save := "res://tmp/l20_finale_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "finale save"):
		await stop(scene, 1); return
	if not check(scene._quickload_unrecorded(save).is_empty(), "finale reload"):
		await stop(scene, 1); return
	end = scene.get_node("L20Finale")
	await process_frame
	card = end.find_child("Stage", true, false) as Label
	var kept: bool = end.finished(end.state()) and bool(end.state().game_finished) and card != null and "The game is finished." in card.text and end.get_node("Credits").visible and scene.player.position.distance_to(before) < 0.1
	if not check(kept, "save keeps the finished flag and the credits"):
		await stop(scene, 1); return
	print("PASS earned final fight: the beats take seconds, the chasm prop shows, and the finished flag keeps the credits")
	await stop(scene, 0)
