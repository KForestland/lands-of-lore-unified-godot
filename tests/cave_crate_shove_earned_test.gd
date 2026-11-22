extends SceneTree
## Owner r17 16-23-39. Walk into crate 94 and keep walking. It moves, then rests on crate 95.
const Stack := preload("res://scripts/lol2/cave_crate_stack.gd")
var failures: int = 0

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL crate: ", label)
	return ok

func _initialize() -> void:
	run.call_deferred()

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func spot(stack: Node, id: int) -> Vector3:
	var centers: Dictionary = stack.get("centers")
	return centers[id] as Vector3

func run() -> void:
	var cave: Node = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	current_scene = cave
	for _i in 1500:
		await process_frame
		if bool(cave.get("walkthrough_ready")):
			break
	if not check(bool(cave.get("walkthrough_ready")), "cave ready"):
		quit(1)
		return
	var stack: Node = cave.get_node_or_null("CaveCrateStack")
	if not check(stack != null, "crate stack hosted"):
		quit(1)
		return
	var magic: Node = cave.get("starting_magic")
	if magic != null:
		magic.set("interface_request", true)
	cave.set_physics_process(false)
	var player: CharacterBody3D = cave.get("player") as CharacterBody3D
	player.set_physics_process(false)
	var home94: Vector3 = spot(stack, 94)
	var home95: Vector3 = spot(stack, 95)
	var toward: Vector3 = home95 - home94
	toward.y = 0.0
	if not check(toward.length() > 1.0, "crates 94 and 95 are apart"):
		quit(1)
		return
	var dir: Vector3 = toward.normalized()
	var sizes: Dictionary = stack.get("sizes")
	var size94: Vector3 = sizes[94] as Vector3
	var start: Vector3 = home94 - dir * 36.0
	start.y = home94.y - size94.y * 0.5 + 32.0
	player.global_position = start
	var moved: bool = false
	var stacked: bool = false
	for _tick in 300:
		await physics_frame
		var now: Vector3 = spot(stack, 94)
		if flat(now, home94) > 3.0:
			moved = true
		if now.y > home94.y + 4.0 and flat(now, home95) < 8.0:
			stacked = true
			break
		var step: Vector3 = home95 - player.global_position
		step.y = 0.0
		if step.length() < 0.01:
			player.velocity = Vector3.ZERO
		else:
			player.velocity = step.normalized() * 60.0
		player.velocity.y = -32.0
		player.move_and_slide()
	var end94: Vector3 = spot(stack, 94)
	if not moved:
		print("crate trace start ", start, " player ", player.global_position, " crate ", end94, " home ", home94, " other ", home95)
	if not check(moved, "walked into crate 94 and it moved"):
		quit(1)
		return
	if not check(stacked and end94.y > home94.y + 4.0, "crate 94 rests on crate 95"):
		quit(1)
		return
	print("PASS crate: walked into crate 94, it moved, and it rests on crate 95")
	quit(0)
