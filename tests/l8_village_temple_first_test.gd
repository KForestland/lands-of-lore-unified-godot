extends SceneTree
## Owner r17 17-53-55: at the village tree with the blade recovered and the temple unvisited,
## the guard says to visit the Huline Temple first. A journal note alone is not the line.
const Journey = preload("res://scripts/lol2/l8_journey.gd")
const State = preload("res://scripts/lol2/l8_journey_state.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

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

func approach(scene: Node, goal: Vector3, stop_at: float) -> void:
	var physics: bool = scene.is_physics_processing()
	scene.set_physics_process(false)
	var stuck: int = 0
	var previous: Vector3 = scene.player.position
	for _tick in 900:
		var journey: Node = scene.get_node("L8Journey")
		if journey.target() == "village":
			break
		var delta: Vector3 = goal - scene.player.position
		delta.y = 0.0
		if delta.length() < stop_at:
			break
		scene.move_grounded(delta.normalized(), 1.0 / 60.0)
		await physics_frame
		var step: float = Vector2(scene.player.position.x - previous.x, scene.player.position.z - previous.z).length()
		previous = scene.player.position
		if step < 0.05:
			stuck += 1
		else:
			stuck = 0
		if stuck >= 25:
			break
	scene.set_physics_process(physics)

func boot() -> Node:
	var scene: Node = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	for _i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	return scene

func run() -> void:
	var scene: Node = await boot()
	if not scene.ready_for_review or scene.get_node_or_null("L8Journey") == null:
		check(false, "darker jungle ready")
		await stop(scene, 1)
		return
	scene.player_form = 0
	scene.flying = false
	scene.quest_state["l8_journey"] = {"version": 1, "gift": "recovered", "temple_visited": false, "admitted": false, "key_awarded": false}
	if State.BLADE not in scene.carried_collected:
		scene.carried_collected.append(State.BLADE)
	# Outside the 160 reach. Owner report (540, -4526) is the stance the walk finishes on.
	var owner := Vector3(540, 32, -4526)
	scene.player.position = Vector3(540, 48, -4300)
	scene.player.velocity = Vector3.ZERO
	var journey: Node = scene.get_node("L8Journey")
	await process_frame
	check(journey.target() != "village" and journey.hint.text != Journey.TEMPLE_FIRST, "the line is absent before the walk, hint '%s'" % journey.hint.text)
	await approach(scene, owner, 8.0)
	await process_frame
	check(journey.target() == "village", "walked to the village tree at %s" % scene.player.position)
	check(str(journey.hint.text) == Journey.TEMPLE_FIRST, "guard line '%s'" % journey.hint.text)
	check(str(scene.interface_hud.hint.text) == Journey.TEMPLE_FIRST, "hud line '%s'" % scene.interface_hud.hint.text)
	var refused: Dictionary = journey.interact("show_guard", State.BLADE)
	check(not refused.ok and not bool(scene.quest_state.l8_journey.admitted) and not bool(scene.quest_state.l8_journey.temple_visited), "the blade does not open the village")
	await key(KEY_E)
	check(journey.opened == "village" and journey.panel.visible, "E opens the guard panel")
	var spoke := false
	var admitted_button := false
	for child in journey.box.get_children():
		if child is Label and str(child.text) == Journey.TEMPLE_FIRST:
			spoke = true
		if child is Button and str(child.text) == "Show Daniel's blade":
			admitted_button = true
	check(spoke and not admitted_button, "the panel is the temple line and has no admission")
	check(not bool(scene.quest_state.l8_journey.admitted), "admission stays closed")
	if failures == 0:
		print("PASS earned L8 village: the guard says to visit the Huline Temple first, and the blade is not admitted")
	await stop(scene, 1 if failures else 0)
