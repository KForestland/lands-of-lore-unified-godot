extends SceneTree
## OF9 (owner F10 2026-11-10 T23-41-20). He stood in L10 region 4148 at (2537, -1819, h -118), walked through a wall
## and fell under the map. Region 4004 shares his room's south side. Its native neighbours on edges 0 and 2 are null
## (walls 2849 and 2848, floor -150 to ceiling -75) and those source walls did not collide. This walk starts in 4004,
## pushes through both walls and through the open side into 4148.
var failures := 0
func check(ok: bool, why: String) -> bool:
	if not ok: failures += 1; printerr("FAIL catacomb void wall: ", why)
	return ok
func _initialize() -> void: run.call_deferred()
func inside(poly: PackedVector2Array, point: Vector3) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), poly)
func ray_hit(scene: Node, a: Vector3, b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a, b, 1, [scene.player.get_rid()])
	return scene.get_world_3d().direct_space_state.intersect_ray(query)
func push(scene: Node, goal: Vector3, ticks: int) -> float:
	var lowest: float = scene.player.position.y
	for _i in ticks:
		var delta: Vector3 = goal - scene.player.position
		delta.y = 0.0
		if delta.length() < 6.0: break
		scene.move_grounded(delta.normalized(), 1.0 / 60.0)
		await physics_frame
		lowest = minf(lowest, scene.player.position.y)
	return lowest
func run() -> void:
	var scene = load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for _i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not check(scene.ready_for_review, "L10 ready"): quit(1); return
	var walls: int = int(scene.edge_rule_counts.get("l10_void_walls", 0))
	if not check(walls > 3000, "void-neighbour source walls on the body (%d)" % walls): quit(1); return
	scene.player.set_physics_process(false)
	scene.set_physics_process(false)
	# Region 4004, floor -150, body origin 32 above the floor. Centroid of the native quad.
	var room := PackedVector2Array([Vector2(2335, -1739), Vector2(2400, -2080), Vector2(2448, -2112), Vector2(2624, -2000)])
	var home := Vector3(2451.75, -118.0, -1982.75)
	scene.player.position = home
	scene.player.velocity = Vector3.ZERO
	for _i in 8:
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame
	if not check(absf(scene.player.position.y + 118.0) < 4.0 and scene.resets == 0, "settled on the catacomb floor (%s resets %d)" % [scene.player.position, scene.resets]): quit(1); return
	# Body height inside the wall span (-150..-75). Each ray starts in the room and ends past the wall.
	var through_0: Dictionary = ray_hit(scene, Vector3(2400, -120, -1960), Vector3(2320, -120, -1860))
	var through_2: Dictionary = ray_hit(scene, Vector3(2500, -120, -2020), Vector3(2580, -120, -2100))
	check(not through_0.is_empty(), "wall 2849 (region 4004 edge 0) blocks a ray (%s)" % str(through_0.get("position", "miss")))
	check(not through_2.is_empty(), "wall 2848 (region 4004 edge 2) blocks a ray (%s)" % str(through_2.get("position", "miss")))
	var past_0 := Vector3(2280, -118, -1840)
	var low_0: float = await push(scene, past_0, 240)
	check(inside(room, scene.player.position) and low_0 > -140.0 and scene.resets == 0, "walk into wall 2849 stays in the room (at %s lowest %.1f resets %d)" % [scene.player.position, low_0, scene.resets])
	scene.player.position = home
	scene.player.velocity = Vector3.ZERO
	var past_2 := Vector3(2580, -118, -2120)
	var low_2: float = await push(scene, past_2, 240)
	check(inside(room, scene.player.position) and low_2 > -140.0 and scene.resets == 0, "walk into wall 2848 stays in the room (at %s lowest %.1f resets %d)" % [scene.player.position, low_2, scene.resets])
	# The shared side with region 4148 is a native neighbour. The walk must still leave 4004 onto his floor.
	scene.player.position = home
	scene.player.velocity = Vector3.ZERO
	var owner_spot := Vector3(2537.2, -118.0, -1818.9)
	var low_door: float = await push(scene, owner_spot, 400)
	var crossed: bool = scene.player.position.distance_to(owner_spot) < 12.0
	check(crossed and low_door > -140.0 and scene.resets == 0, "the open side into region 4148 still walks (at %s lowest %.1f resets %d)" % [scene.player.position, low_door, scene.resets])
	scene.queue_free()
	await process_frame
	if failures == 0: print("PASS L10 catacomb void walls: region 4004 edges 0 and 2 hold, the side into 4148 stays open, resets 0")
	quit(0 if failures == 0 else 1)
