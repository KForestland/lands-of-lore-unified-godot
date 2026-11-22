extends "res://tests/l8_temple_earned_test.gd"
## Darker start, temple first (the owner path). The priest scene fires on the walk.
## The door stays shut and names Daniel. The village does not take the blade yet.

func run() -> void:
	if not check(FileAccess.get_sha256(INPUT) == HASH, "pinned earned Act1 arrival"):
		quit(1)
		return
	var source: Dictionary = Save.read_save(INPUT, "lol2-restoration-darker-jungle")
	if not check(source.error.is_empty(), "earned save validates: " + source.error):
		quit(1)
		return
	set_meta("lol2_darker_resume", source.state)
	Engine.set_meta("lol2_enhanced", false)
	var scene: Node = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for _i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	if not check(scene.ready_for_review, "production scene ready"):
		quit(1)
		return
	scene.player.set_physics_process(false)
	scene.player_form = 0
	scene.flying = false
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_first_departure_walk.json"))
	# Label is not "temple": that id clears itself once the scene fires, and the walk must reach the door.
	if not await walk(scene, route.temple, "sealed-door"):
		quit(1)
		return
	for _frame in 6:
		await process_frame
	var journey: Node = scene.get_node("L8Journey")
	var door: Node = scene.get_node("L8TempleDoor")
	if not check(bool(scene.quest_state.l8_journey.temple_visited), "priest scene fired on the walk"):
		quit(1)
		return
	if not check(str(scene.quest_state.l8_journey.gift) == "unoffered", "the blade was not given to Daniel yet"):
		quit(1)
		return
	# Headless has no window, so a captured mouse does not stick (l8_journey.gd). The shipped
	# Temple-door walk sets interface_request, which is the mouse waiver in movie_world_active().
	scene.starting_magic.interface_request = true
	scene.camera.look_at(door.POINT, Vector3.UP)
	if not check(door.reachable(), "at the Temple door %s (%s)" % [scene.player.position, inactive_reason(scene)]):
		quit(1)
		return
	await process_frame
	var line: String = str(door.hint.text)
	if not check(line.begins_with(door.SEALED) and line.contains("Meet Daniel"), "door line '%s'" % line):
		quit(1)
		return
	await key(KEY_E)
	if not check(str(scene.interface_hud.hint.text) == line, "E repeats the door line '%s'" % scene.interface_hud.hint.text):
		quit(1)
		return
	if not check(scene.progression.level_changes.is_empty(), "the sealed door does not change level"):
		quit(1)
		return
	scene.starting_magic.interface_request = false
	if not await walk(scene, route.village, "village"):
		quit(1)
		return
	await process_frame
	if not check(journey.target() == "village", "walked to the guard at %s" % scene.player.position):
		quit(1)
		return
	var refused: Dictionary = journey.interact("show_guard", State.BLADE)
	if not check(not refused.ok and str(refused.reason) == State.NEED_DANIEL and not bool(scene.quest_state.l8_journey.admitted), "guard refusal '%s'" % str(refused.get("reason", ""))):
		quit(1)
		return
	await key(KEY_E)
	var spoke: bool = false
	var offered: bool = false
	for child in journey.box.get_children():
		if child is Label and State.NEED_DANIEL in str(child.text):
			spoke = true
		if child is Button and str(child.text) == "Show Daniel's blade":
			offered = true
	if not check(spoke and not offered, "the panel names Daniel and does not offer the blade"):
		quit(1)
		return
	if failures == 0:
		print("PASS earned L8 darker start: after the priest scene the sealed door names Daniel, and the guard does not take the blade yet")
	if is_instance_valid(scene):
		scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)

func inactive_reason(scene: Node) -> String:
	var magic: Node = scene.starting_magic
	if scene.has_node("L8HulineSpeech") and scene.get_node("L8HulineSpeech").input_locked():
		return "huline"
	if scene.has_node("L8Tribe") and scene.get_node("L8Tribe").input_locked():
		return "tribe"
	if scene.get("chief_hut") != null and is_instance_valid(scene.chief_hut) and scene.chief_hut.input_locked():
		return "hut"
	if scene.get("kityara") != null and is_instance_valid(scene.kityara) and scene.kityara.movement_locked():
		return "kityara"
	if scene.get_tree().paused:
		return "paused"
	if bool(scene.flying):
		return "flying"
	if int(magic.health()) <= 0:
		return "health"
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not bool(magic.interface_request):
		return "mouse"
	if scene.get_tree().current_scene != null and scene.get_tree().current_scene != scene:
		return "scene"
	if scene.get("interface_hud") != null and bool(scene.interface_hud.cursor_active):
		return "cursor"
	return "other"
func key(code: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = code
	pressed.pressed = true
	Input.parse_input_event(pressed)
	Input.flush_buffered_events()
	await process_frame
	var released := InputEventKey.new()
	released.keycode = code
	released.pressed = false
	Input.parse_input_event(released)
	Input.flush_buffered_events()
	await process_frame
