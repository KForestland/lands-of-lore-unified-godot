extends SceneTree
## Owner r17: the tree bridge and the cache ladder failed in real play. The probes teleported and called use().
## This walk starts at the reported stances, uses E and a weapon chop, and stays on the log and the ledge.
const Bridge = preload("res://scripts/lol2/l8_tree_bridge.gd")
const Ladder = preload("res://scripts/lol2/l8_cache_ladder.gd")
const SWORD := "jungle:kelsrick:Fine_Longsword"
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

func click(scene: Node) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.button_mask = MOUSE_BUTTON_MASK_LEFT
	pressed.pressed = true
	scene.get_viewport().push_input(pressed)
	await process_frame
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	scene.get_viewport().push_input(released)
	await process_frame

## Walk with the player mover. Stop at the goal or when the body is blocked. No seam nudge.
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

func run() -> void:
	var scene: Node = await boot()
	if not scene.ready_for_review or scene.get_node_or_null("L8TreeBridge") == null:
		check(false, "darker jungle ready")
		await stop(scene, 1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.player_form = 0
	scene.equipped_item = ""
	scene.flying = false
	# Owner report 17-57-09. Feet sit on the west bank.
	scene.player.position = Vector3(5034, 40, 1856)
	scene.player.velocity = Vector3.ZERO
	await approach(scene, Bridge.AT, 18.0)
	await process_frame
	var bridge: Node = scene.get_node("L8TreeBridge")
	check(bridge.flat_distance() <= Bridge.REACH, "the walked stance can chop, distance %s at %s" % [bridge.flat_distance(), scene.player.position])
	check(str(scene.interface_hud.hint.text) == "Hold a weapon to chop the tree.", "bare-hand line '%s'" % scene.interface_hud.hint.text)
	await key(KEY_E)
	await click(scene)
	check(not scene.quest_state.has("l8_tree_bridge"), "E and a click with an empty hand leave the tree")
	scene.equipped_item = SWORD
	await process_frame
	check(str(scene.interface_hud.hint.text) == "E — Chop the tree", "weapon line '%s'" % scene.interface_hud.hint.text)
	await click(scene)
	var assemblies: Node = scene.preview_assemblies
	var knocked: bool = scene.quest_state.has("l8_tree_bridge") and bool(scene.quest_state.l8_tree_bridge.knocked)
	check(knocked and assemblies.is_present(Bridge.BRIDGE) and not assemblies.is_present(Bridge.TREE), "the chop links the log")
	await approach(scene, Vector3(5300, 58, 1908), 16.0)
	check(scene.player.position.x > 5240.0 and scene.player.position.y > 10.0, "walked across the log to %s" % scene.player.position)
	var path := "res://tmp/l8_bridge_ladder_earned_save.json"
	scene.equipped_item = ""
	var error: String = scene._quicksave_unrecorded(path)
	check(error.is_empty(), "bridge save: " + error)
	scene.free()
	var again: Node = await boot()
	if not again.ready_for_review:
		check(false, "reload ready")
		await stop(again, 1)
		return
	error = again._quickload_unrecorded(path)
	check(error.is_empty() and bool(again.quest_state.l8_tree_bridge.knocked) and again.preview_assemblies.is_present(Bridge.BRIDGE), "the felled tree survives the save")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	again.player_form = 0
	again.flying = false
	# Owner report 18-08-06.
	again.player.position = Vector3(-1087, 40, -2638)
	again.player.velocity = Vector3.ZERO
	await approach(again, Ladder.AT, 16.0)
	await process_frame
	var ladder: Node = again.get_node("L8CacheLadder")
	check(ladder.flat_distance() <= Ladder.REACH, "the walked stance can climb, distance %s at %s" % [ladder.flat_distance(), again.player.position])
	check(str(again.interface_hud.hint.text) == "E — Climb the ladder", "ladder line '%s'" % again.interface_hud.hint.text)
	await key(KEY_E)
	for _frame in 45:
		again.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame
	var climbed: bool = again.quest_state.has("l8_cache_ladder") and bool(again.quest_state.l8_cache_ladder.climbed)
	check(climbed and Ladder.on_ledge(again.player.position), "climbed and stayed at %s" % again.player.position)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures == 0:
		print("PASS earned L8 tree bridge: Human walked up, chopped with a weapon, and crossed the log; the cache ladder climb stayed on the ledge")
	await stop(again, 1 if failures else 0)
