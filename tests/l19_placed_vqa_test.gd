extends SceneTree
## Stand in front of Dawn's recorded quad, then in front of the placenta quad.
const Reel = preload("res://scripts/lol2/placed_vqa_billboard.gd")
var failures := 0

func check(ok: bool, message: String) -> bool:
	if not ok:
		failures += 1
		print("CHECK " + message)
	return ok

func _initialize() -> void:
	run.call_deferred()

func boot(scene_path: String, node_name: String) -> Node:
	var scene: Node = load(scene_path).instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	var ready := false
	for _i in 300:
		await process_frame
		if scene.ready_for_review and scene.progression != null and scene.get_node_or_null(node_name) != null:
			ready = true
			break
	if not check(ready, scene_path + " ready with " + node_name + ". Stage the reel with the matching prepare script first."):
		return null
	scene.progression.change_scene_enabled = false
	scene.player.set_physics_process(false)
	scene.set_physics_process(false)
	return scene

func watch(scene: Node, bill: Node, points: PackedVector3Array, frames: int, source: String, logical: String) -> void:
	var spot: Vector3 = Reel.stand_at(points)
	scene.player.position = spot
	scene.player.velocity = Vector3.ZERO
	var row: Dictionary = bill.get("media")
	if not check(str(row.get("logical_name", "")) == logical, "logical name"):
		return
	if not check(int(row.frames) == frames and str(row.source_sha256) == source, "frame count and source pin"):
		return
	if not check(FileAccess.get_sha256(str(row.path)) == str(row.sha256), "staged ogv pin"):
		return
	var reel: VideoStreamPlayer = bill.get_node("Viewport/Reel")
	var stream := reel.stream as VideoStreamTheora
	var playing := false
	for _i in 45:
		await process_frame
		if stream != null and str(stream.file) == str(row.path) and reel.is_playing():
			playing = true
			break
	if not check(playing, "the reel is playing"):
		return
	var quad: MeshInstance3D = bill.get_node("Quad")
	var box: AABB = quad.global_transform * quad.get_aabb()
	var lo: Vector3 = points[0]
	var hi: Vector3 = points[0]
	for point in points:
		lo = lo.min(point)
		hi = hi.max(point)
	var placed: bool = box.position.distance_to(lo) < 0.05 and (box.position + box.size).distance_to(hi) < 0.05
	if not check(placed, "quad sits on the recorded corners"):
		return
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var origin := spot + Vector3(0, 20, 0)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3(0, 0, -80), Reel.HIT_LAYER)
	var hit: Dictionary = space.intersect_ray(query)
	var body: Node = bill.get_node("Hit")
	var seen: bool = hit.get("collider") == body and absf(float(hit.position.z) - points[0].z) < 1.0
	check(seen, "the stand sees the quad")

func run() -> void:
	var l19: Node = await boot("res://scenes/lol2/maps/L19_BC.tscn", "L19E224e")
	if l19 == null:
		quit(1)
		return
	var dawn: Node = l19.get_node("L19E224e")
	await watch(l19, dawn, Reel.dawn_corners(), 1256, Reel.E224E_SHA, "SPHERE3\\L19_BC\\E224E.VQA")
	l19.queue_free()
	for _i in 4:
		await process_frame
	var l20: Node = await boot("res://scenes/lol2/maps/L20_BB.tscn", "L20Placenta")
	if l20 == null:
		quit(1)
		return
	var mother: Node = l20.get_node("L20Placenta")
	await watch(l20, mother, Reel.placenta_corners(), 60, Reel.PLACENTA_SHA, "SPHERE3\\L20_BB\\PLACENTA.VQA")
	if failures > 0:
		quit(1)
		return
	print("PASS Dawn's quad plays e224e and the placenta quad plays its reel")
	quit()
