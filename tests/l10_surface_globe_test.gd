extends SceneTree
## OF4 (owner F10 2026-11-10 T23-36-20). He stood at (155, -3704) with origin height -43 and could not take the
## glass globe. Item 47 is at (188, 0, -3756), on the surface floor. Feet at -75 are the catacomb ceiling under
## that floor. Region 1769 is the wide room beside that gap; its edge 2 (wall 3105, y -150 to -75) has no native
## neighbour. This walk refuses the globe from the reported height, takes it from the surface, and pushes that wall.
var failures := 0
func check(ok: bool, why: String) -> bool:
	if not ok:
		failures += 1
		printerr("FAIL surface globe: ", why)
	return ok
func _initialize() -> void:
	run.call_deferred()
func inside(poly: PackedVector2Array, point: Vector3) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), poly)
func push(scene: Node, goal: Vector3, ticks: int) -> float:
	var lowest: float = scene.player.position.y
	for _i in ticks:
		var delta: Vector3 = goal - scene.player.position
		delta.y = 0.0
		if delta.length() < 6.0:
			break
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
		if scene.ready_for_review:
			break
	if not check(scene.ready_for_review, "L10 ready"):
		quit(1)
		return
	scene.player.set_physics_process(false)
	scene.set_physics_process(false)
	var item := "act2:L10_DC:item47"
	scene.player.position = Vector3(155.0, 32.0, -3704.0)
	scene.player.velocity = Vector3.ZERO
	for _i in 8:
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame
	if not check(absf(scene.player.position.y - 32.0) < 4.0 and scene.resets == 0, "settled on the surface floor (%s resets %d)" % [scene.player.position, scene.resets]):
		quit(1)
		return
	scene.player.position = Vector3(155.0, -43.0, -3704.0)
	scene.player.velocity = Vector3.ZERO
	scene.camera.look_at(scene.act2_items.aim_point(item), Vector3.UP)
	check(not scene.act2_items.take(item), "the reported height under the floor cannot take globe 47 (at %s)" % scene.player.position)
	scene.player.position = Vector3(155.0, 32.0, -3704.0)
	scene.player.velocity = Vector3.ZERO
	for _i in 8:
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame
	if not check(absf(scene.player.position.y - 32.0) < 4.0 and scene.resets == 0, "settled on the surface floor (%s resets %d)" % [scene.player.position, scene.resets]):
		quit(1)
		return
	scene.camera.look_at(scene.act2_items.aim_point(item), Vector3.UP)
	var took: bool = scene.act2_items.take(item)
	check(took and item in scene.carried_collected, "E takes globe 47 from the surface (at %s aim %s)" % [scene.player.position, scene.act2_items.aim_point(item)])
	var room := PackedVector2Array([Vector2(-240, -3872), Vector2(-288, -4048), Vector2(-112, -4048), Vector2(-128, -3872)])
	var home := Vector3(-192.0, -118.0, -3960.0)
	scene.player.position = home
	scene.player.velocity = Vector3.ZERO
	for _i in 8:
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame
	if not check(absf(scene.player.position.y + 118.0) < 4.0 and inside(room, scene.player.position), "settled in region 1769 (%s)" % scene.player.position):
		quit(1)
		return
	var low_wall: float = await push(scene, Vector3(-40.0, -118.0, -3960.0), 240)
	check(inside(room, scene.player.position) and low_wall > -140.0 and scene.resets == 0, "walk into wall 3105 stays in the room (at %s lowest %.1f resets %d)" % [scene.player.position, low_wall, scene.resets])
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("PASS L10 surface globe: item 47 is refused under the floor and taken from it, region 1769 edge 2 holds, resets 0")
	quit(0 if failures == 0 else 1)
