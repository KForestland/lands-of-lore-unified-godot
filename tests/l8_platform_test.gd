extends SceneTree
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
	var scene: Node = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	for _i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not scene.ready_for_review or scene.get_node_or_null("L8Tree") == null:
		check(false, "darker jungle platform ready")
		await stop(scene, 1)
		return
	var tree: Node = scene.get_node("L8Tree")
	var stair: CollisionObject3D = tree.floors["663"].get_node("Collision")
	check(stair.collision_layer == 1 << 8, "stair collision is on layer 9")
	check(tree.gate.get_node("Collision").collision_layer == 1, "the bamboo door stays on layer 1")
	var torches: int = 0
	for child in tree.get_children():
		if child is StaticBody3D and child.has_meta("spark_receiver"):
			torches += 1
			check(child.collision_layer == 1, "torch %s stays on layer 1" % child.name)
	check(torches == 5, "five torch solids")
	check((scene.player.collision_mask & (1 << 8)) != 0, "the player still collides with layer 9")
	if failures == 0: print("PASS l8 platform: stairs on layer 9, torches on layer 1")
	await stop(scene, 1 if failures else 0)
