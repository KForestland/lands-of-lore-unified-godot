extends SceneTree
## Owner r18 F10 15-30-40 at (-1092,-2627): the cache ladder worked once.
## Walk in from outside reach, climb up, save, reload, climb down, climb up again.
const Ladder = preload("res://scripts/lol2/l8_cache_ladder.gd")
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
	for _tick in 700:
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

func stand_still(scene: Node) -> void:
	for _frame in 45:
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame

func run() -> void:
	var scene: Node = await boot()
	if not scene.ready_for_review or scene.get_node_or_null("L8CacheLadder") == null:
		check(false, "darker jungle ladder ready")
		await stop(scene, 1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.player_form = 0
	scene.flying = false
	var report := Vector3(-1092.0, 22.0, -2627.0)
	var at := Vector3(Ladder.AT.x, report.y, Ladder.AT.z)
	var away: Vector3 = report - at
	away.y = 0.0
	var start: Vector3 = at + away.normalized() * 120.0
	scene.player.position = start
	scene.player.velocity = Vector3.ZERO
	var ladder: Node = scene.get_node("L8CacheLadder")
	check(ladder.flat_distance() > Ladder.REACH, "the walk must start outside reach, distance %s" % ladder.flat_distance())
	await approach(scene, report, 12.0)
	await process_frame
	check(ladder.flat_distance() <= Ladder.REACH and ladder._at_base(), "the walk reached the base at %s" % scene.player.position)
	check(str(scene.interface_hud.hint.text) == "E — Climb the ladder", "base line '%s'" % scene.interface_hud.hint.text)
	await key(KEY_E)
	await stand_still(scene)
	var climbed: bool = scene.quest_state.has("l8_cache_ladder") and bool(scene.quest_state.l8_cache_ladder.climbed)
	check(climbed and Ladder.on_ledge(scene.player.position), "the first climb stays on the ledge at %s" % scene.player.position)
	var path := "user://tests/l8_cache_ladder_repeat.json"
	var error: String = scene._quicksave_unrecorded(path)
	check(error.is_empty(), "ledge save: " + error)
	scene.free()
	var again: Node = await boot()
	if not again.ready_for_review:
		check(false, "reload ready")
		await stop(again, 1)
		return
	error = again._quickload_unrecorded(path)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	again.player_form = 0
	again.flying = false
	var again_ladder: Node = again.get_node("L8CacheLadder")
	await process_frame
	var still: bool = again.quest_state.has("l8_cache_ladder") and bool(again.quest_state.l8_cache_ladder.climbed)
	check(error.is_empty() and still and Ladder.on_ledge(again.player.position), "the ledge and the saved climb survive reload at %s" % again.player.position)
	check(str(again.interface_hud.hint.text) == "E — Climb down", "shelf line '%s'" % again.interface_hud.hint.text)
	await key(KEY_E)
	await stand_still(again)
	check(again_ladder._at_base() and not Ladder.on_ledge(again.player.position), "the reload climb comes back down at %s" % again.player.position)
	check(str(again.interface_hud.hint.text) == "E — Climb the ladder", "second base line '%s'" % again.interface_hud.hint.text)
	await key(KEY_E)
	await stand_still(again)
	check(Ladder.on_ledge(again.player.position), "the climb after the reload goes back up at %s" % again.player.position)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures == 0:
		print("PASS l8 cache ladder: walked in from outside reach, climbed up, saved, reloaded, climbed down, and climbed up again")
	await stop(again, 1 if failures else 0)
