extends SceneTree
## Owner r17 17-50-18, 17-50-38 and 17-50-53. The bark sheets above the hedge are gone.
## The hedge face under the first sheet stays.
const Jungle := preload("res://scripts/lol2/darker_jungle.gd")
const Review := preload("res://scripts/lol2/jungle_review.gd")
const POSES: Array[Vector3] = [Vector3(-2386.9, 32.0, 589.3), Vector3(-3794.0, 32.0, 979.6), Vector3(-3797.3, 32.0, 1400.9)]
const YAW: Array[float] = [-2.080, -0.146, -2.948]
const PITCH: Array[float] = [0.504, 0.459, 0.429]
## Short rays through the five risers, then one through the hedge face 7533 that stays.
const RAYS: Array[Vector3] = [
	Vector3(-2312.82, 130.0, 638.31), Vector3(-2297.18, 130.0, 641.69),
	Vector3(-3831.31, 130.0, 1543.54), Vector3(-3829.69, 130.0, 1559.46),
	Vector3(-3634.54, 130.0, 1475.12), Vector3(-3625.07, 130.0, 1488.02),
	Vector3(-3630.15, 130.0, 862.03), Vector3(-3627.71, 130.0, 846.21),
	Vector3(-3833.5, 130.0, 849.0), Vector3(-3833.5, 130.0, 833.0),
	Vector3(-2318.14, 30.0, 617.5), Vector3(-2333.86, 30.0, 614.5)
]
var failures: int = 0

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL hedge riser: ", label)
	return ok

func _initialize() -> void:
	run.call_deferred()

func crosses(scene: Jungle, a: Vector3, b: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a, b, Review.PROJECTILE_WALL_LAYER)
	query.hit_from_inside = true
	return not scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

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
	for i in POSES.size():
		scene.player.position = Vector3(POSES[i].x, 48.0, POSES[i].z)
		scene.player.velocity = Vector3.ZERO
		scene.player.rotation.y = YAW[i]
		scene.camera.rotation.x = PITCH[i]
		for _frame in 8:
			await physics_frame
		var flat: float = Vector2(scene.player.position.x - POSES[i].x, scene.player.position.z - POSES[i].z).length()
		if not check(flat < 20.0 and scene.player.position.y > -5.0 and scene.player.position.y < 80.0, "stood pose %d at %s" % [i, scene.player.position]):
			scene.queue_free()
			quit(1)
			return
	for i in 5:
		var hit: bool = crosses(scene, RAYS[i * 2], RAYS[i * 2 + 1])
		if not check(not hit, "riser %d still crosses the look" % i):
			scene.queue_free()
			quit(1)
			return
	if not check(crosses(scene, RAYS[10], RAYS[11]), "the hedge under the first sheet is gone"):
		scene.queue_free()
		quit(1)
		return
	print("PASS hedge: stood the three looks, the five bark sheets are gone, and the hedge under the first one stays")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
