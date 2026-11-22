extends SceneTree
## BK00a. Stand on L19 region 40. Movable 77's kind-6 caller 15 runs group 7898.
## The floor rises from -40 to -20 and the body rises with it.
var failures := 0
func check(ok: bool, message: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL: " + message)
	return ok
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var scene: Node = load("res://scenes/lol2/maps/L19_BC.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	for _i in 60:
		await process_frame
		if scene.ready_for_review and scene.progression != null:
			break
	if not check(scene.ready_for_review and scene.progression != null, "L19 ready"):
		quit(1)
		return
	check(scene.progression.get_node_or_null("FloorMotions/Floor40") == null, "region 40 stays in the static mesh until group 7898 runs")
	scene.player.set_physics_process(false)
	scene.player.position = Vector3(-301.5, -8.0, -1876.5)
	scene.player.velocity = Vector3.ZERO
	await process_frame
	var results: Array = scene.progression.fire("movable:77", 6, {"caller_byte": 15})
	var deck: Node3D = scene.progression.get_node_or_null("FloorMotions/Floor40")
	if not check(deck != null, "region 40 becomes a floor deck when group 7898 runs"):
		scene.queue_free()
		quit(1)
		return
	var ran := false
	for row in results:
		if int(row.group) == 7898 and str(row.status) == "ran":
			ran = true
	if not check(ran, "group 7898 runs"):
		scene.queue_free()
		quit(1)
		return
	var rose := false
	for _step in 500:
		await physics_frame
		if int(scene.progression.regions[40][1]) == -20:
			rose = true
			break
	var player_y: float = scene.player.position.y
	check(rose and absf(deck.position.y - 20.0) < 0.1 and absf(player_y - 12.0) < 0.1, "region 40 rises to -20 and the player rises with it (floor %s deck %s player %s)" % [scene.progression.regions[40][1], deck.position.y, player_y])
	check(int(scene.progression.regions[61][1]) == -20, "region 61 rises with the same group")
	if failures == 0:
		print("PASS opcode 196 raises region 40 to -20 and the player rises with the floor")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
