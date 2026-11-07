extends SceneTree
const Bridge = preload("res://scripts/lol2/l8_tree_bridge.gd")
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

func run() -> void:
	check(not Bridge.OP9_ENTERED and not Bridge.OP20_PLAYED, "opcode 9 and opcode 20 stay unplayed")
	check(Bridge.validate(Bridge.initial(), {}).is_empty(), "initial bridge state")
	var scene: Node = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	for _i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not scene.ready_for_review or scene.get_node_or_null("L8TreeBridge") == null:
		check(false, "darker jungle bridge ready")
		await stop(scene, 1)
		return
	var bridge: Node = scene.get_node("L8TreeBridge")
	var assemblies: Node = scene.preview_assemblies
	check(assemblies.is_present(Bridge.TREE) and not assemblies.is_present(Bridge.BRIDGE), "the standing tree starts present and the log starts absent")
	check(not assemblies.presence.has(115), "the little branch stays unmanaged")
	check(assemblies.solid_bodies[Bridge.TREE].collision_layer == 1 << 8, "the standing tree collides")
	check(assemblies.solid_bodies[Bridge.BRIDGE].collision_layer == 0, "the absent log stays walkable")
	scene.player.position = Vector3(0, 32, 0)
	check(not bridge.use(), "a far E leaves the tree standing")
	scene.player.position = Vector3(5063, 32, 1888)
	scene.flying = true
	check(not bridge.use(), "flying leaves the tree standing")
	scene.flying = false
	check(bridge.use() and bool(scene.quest_state.l8_tree_bridge.knocked), "the owner point knocks the tree")
	check(not assemblies.is_present(Bridge.TREE) and assemblies.is_present(Bridge.BRIDGE), "assembly 114 unlinks and assembly 116 links")
	check(assemblies.solid_bodies[Bridge.TREE].collision_layer == 0 and assemblies.solid_bodies[Bridge.BRIDGE].collision_layer == 1 << 8, "the log becomes the solid")
	check(preload("res://scripts/lol2/act_one_quest_state.gd").validate(scene.quest_state).is_empty(), "quest validate")
	if failures == 0: print("PASS l8 tree bridge: E at control 114 links the placed log")
	await stop(scene, 1 if failures else 0)
