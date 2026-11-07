extends SceneTree
## Native player-impassable regions (region word +0x1C bit0, B0D98/AFF85) in the live Jungle, with ordinary input:
## holding W (and jumping) from region1846 toward floorless region4544 stops at their shared edge (the owner's 2026-10-23
## "missing wall" report 45 spot); a player placed inside 4544 walks out; layer-1 rays pass the blockers; regions that
## op197 toggles at runtime (Bacatta seal 3501, dam burrow 4543, gates 3805/3811) are not blocked statically.
const Blockers := preload("res://scripts/lol2/region_blockers.gd")
var scene
var failed := false
var held_keys: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true; release_all(); push_error(message); print("FAIL jungle_region_blockers: ", message); quit(1)
	return ok
func key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new(); e.physical_keycode = code; e.keycode = code; e.pressed = pressed
	Input.parse_input_event(e)
	if pressed and code not in held_keys: held_keys.append(code)
	if not pressed: held_keys.erase(code)
func release_all() -> void:
	for code in held_keys.duplicate(): key(code, false)
func face(target: Vector2) -> void:
	var p: Vector3 = scene.player.global_position
	var offset := target - Vector2(p.x, p.z)
	var turn := wrapf(atan2(-offset.x, -offset.y) - scene.player.rotation.y, -PI, PI)
	var m := InputEventMouseMotion.new(); m.relative = Vector2(-turn / 0.003, 0); Input.parse_input_event(m)
## Signed distance of the player from the edge line, positive on the passable (region1846) side.
func side(edge: Dictionary) -> float:
	var a := Vector2(edge.a[0], edge.a[1]); var b := Vector2(edge.b[0], edge.b[1])
	var n := (b - a).orthogonal().normalized()
	if n.dot(Vector2(edge.inside[0], edge.inside[1]) - a) < 0: n = -n
	var p: Vector3 = scene.player.global_position
	return n.dot(Vector2(p.x, p.z) - a)
func walk(target: Vector2, frames: int, jump := false) -> void:
	key(KEY_W, true)
	for i in frames:
		if i % 20 == 0: face(target)
		if jump and i % 45 == 10: key(KEY_SPACE, true)
		if jump and i % 45 == 14: key(KEY_SPACE, false)
		await physics_frame
	release_all()

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate(); scene.region_blockers_enabled = true
	root.add_child(scene); current_scene = scene
	for i in range(1500):
		await process_frame
		if scene.get("ready_for_review"): break
	if not check(scene.get("ready_for_review"), "Jungle not ready"): return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var body := scene.get_node_or_null("RegionBlockers") as StaticBody3D
	if not check(body != null and body.collision_layer == Blockers.LAYER and scene.player.collision_mask & Blockers.LAYER != 0, "Blockers not attached to the player"): return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Blockers.path_for("L4_HJ")))
	data.blocked_regions = data.blocked_regions.map(func(n): return int(n))
	if not check(4544 in data.blocked_regions and 1846 not in data.blocked_regions, "Region flags differ from the source"): return
	for id in [3501, 4543, 3805, 3811]:
		if not check(int(id) not in data.blocked_regions and data.edges.all(func(e): return int(e.blocked) != id), "Runtime-toggled region %d blocked statically" % id): return
	var edge: Dictionary = data.edges.filter(func(e): return int(e.region) == 1846 and int(e.blocked) == 4544)[0]
	var a := Vector2(edge.a[0], edge.a[1]); var b := Vector2(edge.b[0], edge.b[1])
	var middle := (a + b) * 0.5
	var across := (b - a).orthogonal().normalized()
	if across.dot(Vector2(edge.inside[0], edge.inside[1]) - a) > 0: across = -across
	# 1. Walking and jumping from 1846 into 4544 stops at the edge.
	scene.player.global_position = Vector3(middle.x - across.x * 50, 40, middle.y - across.y * 50); scene.player.velocity = Vector3.ZERO
	for i in 30: await physics_frame
	if not check(side(edge) > 40, "Start is not inside region1846 (%.1f)" % side(edge)): return
	await walk(middle + across * 80, 240)
	if not check(side(edge) > -0.5 and side(edge) < 16, "Walking did not stop at the region4544 edge (%.1f)" % side(edge)): return
	await walk(middle + across * 80, 240, true)
	if not check(side(edge) > -0.5, "Jumping crossed into region4544 (%.1f)" % side(edge)): return
	# 2. Placed inside 4544 (as an old save could), the player walks out.
	scene.player.global_position = Vector3(middle.x + across.x * 30, 40, middle.y + across.y * 30); scene.player.velocity = Vector3.ZERO
	for i in 20: await physics_frame
	await walk(middle - across * 60, 240)
	if not check(side(edge) > 10, "Could not walk out of region4544 (%.1f)" % side(edge)): return
	# 3. Aim/sight rays (layer 1) pass the blockers.
	var from := Vector3(middle.x - across.x * 20, 30, middle.y - across.y * 20)
	var to := Vector3(middle.x + across.x * 20, 30, middle.y + across.y * 20)
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	if not check(hit.is_empty() or hit.collider != body, "A layer-1 ray hit the blockers"): return
	var blocked: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Blockers.LAYER))
	if not check(not blocked.is_empty() and blocked.collider == body, "The blocker is not on the region4544 edge"): return
	print("PASS jungle_region_blockers: %d native bit0 edges; W and jumps stop at the 1846/4544 edge, a player inside 4544 walks out, layer-1 rays pass, runtime-toggled regions excluded" % data.edges.size())
	quit(0)
