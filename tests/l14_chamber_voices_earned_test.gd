extends "res://tests/l12_logs_approach_earned_test.gd"
## STORY-066: earned Belial-defeat save -> physical walk to the Chamber of Voice doors -> real E opens the CHV room ->
## refusals keep the Dreamstone -> offering it plays the CITY movie -> native local22 + prop170 kind 6 request level 16
## arrival 1 (opcode 2 arm 0x1C). No seeding: adapter_exit_seeds off, no repositioning after the save loads.
func key(code: Key) -> void:
	var e := InputEventKey.new(); e.keycode = code; e.pressed = true
	Input.parse_input_event(e); Input.flush_buffered_events()
	await process_frame
	e = InputEventKey.new(); e.keycode = code; e.pressed = false
	Input.parse_input_event(e); Input.flush_buffered_events()
	await process_frame

func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l14_belial_combat_qualified_save.json"
	if not check(FileAccess.file_exists(path), "qualified Belial defeat save"): quit(1); return
	var input = Save.read_save(path, "lol2-restoration-map-L14_HT")
	if not check(input.error.is_empty(), str(input.error)): quit(1); return
	var scene = load("res://scenes/lol2/maps/L14_HT.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not check(scene.apply_save(input.state).is_empty(), "earned Belial defeat input"): quit(1); return
	prepare(scene)
	scene.progression.change_scene_enabled = false
	var chv = scene.get_node("L14ChamberVoices")
	if not check(chv.belial_dead() and chv.carried_dreamstone() == chv.DREAMSTONE, "Belial dead and Dreamstone carried in the earned save"): quit(1); return
	if not await walk(scene, [[400, 11000], [600, 10850]], "chamber doors"): quit(1); return
	scene.camera.look_at(chv.DOORS[0], Vector3.UP)
	await process_frame
	await process_frame
	if not check(chv.door_in_reach() and chv.hint.text == "E — Enter the Chamber of Voices", "door prompt in reach"): quit(1); return
	await key(KEY_E)
	if not check(chv.inside and chv.phase == "voices" and paused, "real E opens the CHV room with the voices movie"): quit(1); return
	await key(KEY_SPACE)
	if not check(chv.phase == "idle", "voices skip to the chalice"): quit(1); return
	# Refusal: the Dreamstone kept aside, the chalice refuses and nothing is consumed.
	var stone: String = chv.carried_dreamstone()
	scene.carried_collected.erase(stone)
	if not check(not chv.offer().ok and not chv.state().offered, "no Dreamstone -> refused"): quit(1); return
	scene.carried_collected.append(stone)
	# Esc leaves and the door reopens the room.
	await key(KEY_ESCAPE)
	if not check(not chv.inside and not paused, "Esc leaves the room"): quit(1); return
	await key(KEY_E)
	if not check(chv.inside, "door reopens the room"): quit(1); return
	await key(KEY_SPACE)
	# A real click on the chalice hotspot offers the Dreamstone.
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	click.position = chv.panel.position + Vector2(295, 150) * chv.panel.scale.x
	Input.parse_input_event(click); Input.flush_buffered_events()
	await process_frame
	if not check(chv.state().offered and chv.phase == "city" and chv.carried_dreamstone().is_empty(), "chalice click consumes the Dreamstone and plays CITY"): quit(1); return
	if not check(not chv.offer().ok, "repeat offer refused"): quit(1); return
	var before: int = scene.progression.level_changes.size()
	await key(KEY_SPACE)
	for i in 10: await process_frame
	var changes: Array = scene.progression.level_changes
	if not check(changes.size() == before + 1 and int(changes[-1].level) == 16 and int(changes[-1].selector) == 1, "native prop170 group 9210 requests L16 arrival 1: " + str(changes)): quit(1); return
	if not check(not paused and scene.progression.seeds_applied.is_empty(), "world resumes, no seeds"): quit(1); return
	var error: String = scene._quicksave_unrecorded("res://tmp/l14_chamber_voices_earned_save.json")
	if not check(error.is_empty(), "post-offer save: " + error): quit(1); return
	# Real scene change to the Ancient City with the area handoff (no seeds).
	scene.progression.change_scene_enabled = true; scene.progression._change_level(changes[-1]); await scene_changed
	scene = current_scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	prepare(scene)
	if not check(scene.area_id == "L16_CA" and scene.start_selector == 1 and scene.player.position.distance_to(Vector3(-3860, scene.player.position.y, -1341)) < 2.0, "L16 arrival 1 at native (-3860,1341): %s" % scene.player.position): quit(1); return
	if not check(not "act2:L13_RC:dreamstone" in scene.carried_collected and scene.quest_state.get("l14_chamber_voices",{}).get("offered",false), "Dreamstone stays consumed across the level change"): quit(1); return
	error = scene._quicksave_unrecorded("res://tmp/l16_arrival_earned_save.json")
	if not check(error.is_empty(), "L16 arrival save: " + error): quit(1); return
	scene.queue_free(); await process_frame
	if failures == 0: print("PASS earned Belial defeat -> walk -> real E Chamber door -> refusal/leave/reopen -> chalice click consumes Dreamstone -> CITY -> native L16 arrival 1 -> real scene change and arrival save")
	quit(1 if failures else 0)
