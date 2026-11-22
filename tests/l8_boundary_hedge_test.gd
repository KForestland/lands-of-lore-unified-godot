extends SceneTree
## Owner r17 17-59-34 at (1842, 2499). The hedge on the path is a neighbour-less edge.
## Walking into it stops. The path beside it still walks. A hedge between two regions stays open.
const Jungle := preload("res://scripts/lol2/darker_jungle.gd")
const Review := preload("res://scripts/lol2/jungle_review.gd")
const POSE := Vector3(1842.3, 32.0, 2499.8)
const WALL_A := Vector2(1815.0, 2515.0)
const WALL_B := Vector2(1796.0, 2298.0)
## Short ray through source wall 8693, then one through linked hedge 6959 (region 23 edge 2).
const RAYS: Array[Vector3] = [
	Vector3(1797.53, 30.0, 2407.20), Vector3(1813.47, 30.0, 2405.80),
	Vector3(-3309.74, 30.0, 1335.73), Vector3(-3306.86, 30.0, 1351.47)
]
const PATH := Vector3(1875.0, 32.0, 2560.0)
var failures: int = 0

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL boundary hedge: ", label)
	return ok

func _initialize() -> void:
	run.call_deferred()

func inside_distance(pos: Vector3) -> float:
	var edge := WALL_B - WALL_A
	var inward := Vector2(edge.y, -edge.x)
	if inward.dot(Vector2(POSE.x - WALL_A.x, POSE.z - WALL_A.y)) < 0.0:
		inward = -inward
	return Vector2(pos.x - WALL_A.x, pos.z - WALL_A.y).dot(inward.normalized())

func crosses(scene: Jungle, a: Vector3, b: Vector3, mask: int) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a, b, mask)
	query.hit_from_inside = true
	return not scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func slide(scene: Jungle, goal: Vector3, allowance: int) -> void:
	var stuck: int = 0
	var previous := scene.player.position
	for _tick in allowance:
		await physics_frame
		var delta: Vector3 = goal - scene.player.position
		delta.y = 0.0
		if delta.length() < 12.0:
			return
		scene.player.velocity = delta.normalized() * 80.0
		scene.player.velocity.y = -32.0
		scene.player.move_and_slide()
		var step: float = Vector2(scene.player.position.x - previous.x, scene.player.position.z - previous.z).length()
		previous = scene.player.position
		if step < 0.05:
			stuck += 1
		else:
			stuck = 0
		if stuck >= 6:
			return

func run() -> void:
	var scene: Jungle = load("res://scenes/lol2/darker_jungle.tscn").instantiate() as Jungle
	if scene == null:
		check(false, "darker jungle scene")
		quit(1)
		return
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for _i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	if not check(scene.ready_for_review, "darker jungle ready"):
		scene.queue_free()
		quit(1)
		return
	scene.player.position = Vector3(POSE.x, 48.0, POSE.z)
	scene.player.velocity = Vector3.ZERO
	scene.player.rotation.y = 0.180
	scene.camera.rotation.x = 0.072
	for _frame in 8:
		await physics_frame
	var flat: float = Vector2(scene.player.position.x - POSE.x, scene.player.position.z - POSE.z).length()
	if not check(flat < 20.0 and scene.player.position.y > -5.0 and scene.player.position.y < 80.0, "stood at %s" % scene.player.position):
		scene.queue_free()
		quit(1)
		return
	if not check(crosses(scene, RAYS[0], RAYS[1], 1), "the path hedge has no movement wall"):
		scene.queue_free()
		quit(1)
		return
	if not check(crosses(scene, RAYS[0], RAYS[1], Review.PROJECTILE_WALL_LAYER), "the path hedge is not drawn"):
		scene.queue_free()
		quit(1)
		return
	if not check(not crosses(scene, RAYS[2], RAYS[3], 1), "a linked hedge blocks the walk"):
		scene.queue_free()
		quit(1)
		return
	if not check(crosses(scene, RAYS[2], RAYS[3], Review.PROJECTILE_WALL_LAYER), "the linked hedge is not drawn"):
		scene.queue_free()
		quit(1)
		return
	var physics: bool = scene.is_physics_processing()
	scene.set_physics_process(false)
	var outward := Vector3(POSE.x, scene.player.position.y, POSE.z)
	var away := Vector2(POSE.x - WALL_A.x, POSE.z - WALL_A.y)
	var edge := WALL_B - WALL_A
	var inward := Vector2(edge.y, -edge.x).normalized()
	if inward.dot(away) < 0.0:
		inward = -inward
	outward += Vector3(-inward.x, 0.0, -inward.y) * 90.0
	await slide(scene, outward, 90)
	var gap: float = inside_distance(scene.player.position)
	if not check(gap > 8.0, "walked through the hedge, gap %s at %s" % [gap, scene.player.position]):
		scene.set_physics_process(physics)
		scene.queue_free()
		quit(1)
		return
	await slide(scene, PATH, 160)
	var progressed: float = Vector2(scene.player.position.x - POSE.x, scene.player.position.z - POSE.z).length()
	var along: float = Vector2(scene.player.position.x - PATH.x, scene.player.position.z - PATH.z).length()
	if not check(along < 25.0 and progressed > 40.0, "the path beside the hedge did not walk, at %s" % scene.player.position):
		scene.set_physics_process(physics)
		scene.queue_free()
		quit(1)
		return
	scene.set_physics_process(physics)
	print("PASS hedge walk: stood at (1842,2499), the boundary hedge stopped the walk, and the path beside it still walks")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
