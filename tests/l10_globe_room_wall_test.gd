extends "res://tests/helpers/real_input_player.gd"
## OF6 (owner F10 2026-11-10 T23-38-40). He stood in the globe room at (-529, -4058, h 32) after clipping a wall,
## and the take of item 46 had already succeeded. The south face at z -4286 is walls 5503, 5505 and 5514
## (regions 1444, 1447 and 1452, edge 0). The yard is outside, so the OF9 probe left them open.
## The way in is maus doors 124 and 125, now using generic E rather than the old
## contact adapter. Supplied yard/catacomb vantages and held NPCs: a component,
## not an earned campaign. All movement, aiming, opening and pickup use input.
var failures := 0
func check(ok: bool, why: String) -> bool:
	if not ok:
		failures += 1
		printerr("FAIL globe room: ", why)
	return ok
func _initialize() -> void:
	run.call_deferred()
func inside(poly: PackedVector2Array, point: Vector3) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), poly)
func ray_hit(scene: Node, a: Vector3, b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a, b, 1, [scene.player.get_rid()])
	return scene.get_world_3d().direct_space_state.intersect_ray(query)
func settle(scene: Node, where: Vector3) -> void:
	key_event(KEY_W,false)
	scene.player.position = where
	scene.player.velocity = Vector3.ZERO
	for _i in 8:
		await physics_frame
func push(scene: Node, goal: Vector3, ticks: int) -> void:
	for _i in ticks:
		var delta: Vector3 = goal - scene.player.position
		delta.y = 0.0
		if delta.length() < 8.0:
			break
		var point:Vector3=scene.camera.global_position+delta.normalized()*200
		turn_step(point,false)
		key_event(KEY_W,absf(yaw_error(point))<0.6)
		await physics_frame
	key_event(KEY_W,false)
func run() -> void:
	scene = load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
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
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	use_guard=false
	scene.act2_creatures.set_physics_process(false)
	var yard := PackedVector2Array([Vector2(-727, -4339), Vector2(-312, -4327), Vector2(-311, -4259), Vector2(-764, -4258)])
	await settle(scene, Vector3(-513.0, 32.0, -4310.0))
	if not check(absf(scene.player.position.y - 32.0) < 4.0 and scene.resets == 0 and inside(yard, scene.player.position), "settled in the yard south of wall 5503 (%s resets %d)" % [scene.player.position, scene.resets]):
		quit(1)
		return
	var ray_5503: Dictionary = ray_hit(scene, Vector3(-513, 40, -4320), Vector3(-513, 40, -4240))
	var ray_5505: Dictionary = ray_hit(scene, Vector3(-416, 40, -4320), Vector3(-416, 40, -4240))
	var ray_5514: Dictionary = ray_hit(scene, Vector3(-612, 40, -4320), Vector3(-612, 40, -4240))
	check(not ray_5503.is_empty(), "wall 5503 blocks a ray (%s)" % str(ray_5503.get("position", "miss")))
	check(not ray_5505.is_empty(), "wall 5505 blocks a ray (%s)" % str(ray_5505.get("position", "miss")))
	check(not ray_5514.is_empty(), "wall 5514 blocks a ray (%s)" % str(ray_5514.get("position", "miss")))
	await push(scene, Vector3(-513.0, 32.0, -4200.0), 240)
	check(scene.player.position.z < -4270.0 and scene.player.position.y > 20.0 and scene.resets == 0, "walk into wall 5503 stays in the yard (at %s resets %d)" % [scene.player.position, scene.resets])
	var doors: Node = scene.get_node_or_null("GenericObjects")
	if not check(doors != null, "maus door host is on the map"):
		quit(1)
		return
	await settle(scene, Vector3(-348.0, -118.0, -3795.0))
	var stood: Vector3 = scene.player.position
	if not check(stood.y < -40.0 and scene.resets == 0, "stood in the catacomb under maus door 124 (at %s resets %d)" % [stood, scene.resets]):
		quit(1)
		return
	var binding:Node=scene.progression
	for id in [124,125]:
		if not check(binding.hinges.has(id),"Both native maus leaves are hosted"):quit(1);return
		check(binding.native.field("movable:%d"%id,"state_0x55",0)==0,"Walking below does not open leaf%d"%id)
		var aim:Vector3=binding.hinges[id].global_transform*binding.mover_bounds[id].get_center()
		await look(aim)
		await tap(KEY_E)
		check(binding.native.field("movable:%d"%id,"state_0x55",0)==0,"Catacomb ceiling blocks realE to surface leaf%d"%id)
	await settle(scene, Vector3(-280.0, 32.0, -3824.0))
	if not check(absf(scene.player.position.y - 32.0) < 6.0 and scene.resets == 0 and scene.player.position.x > -310.0, "settled in the east yard by the maus door (%s resets %d)" % [scene.player.position, scene.resets]):
		quit(1)
		return
	var shut: Dictionary = ray_hit(scene, Vector3(-280, 40, -3795), Vector3(-450, 40, -3795))
	check(not shut.is_empty(), "maus door 124 blocks the shut lane (%s)" % str(shut.get("position", "miss")))
	for id in [124,125]:
		var aim:Vector3=binding.hinges[id].global_transform*binding.mover_bounds[id].get_center()
		await look(aim)
		if not check(doors.aimed().get("id")==id,"Real aim selects leaf%d"%id):quit(1);return
		await tap(KEY_E)
		for tick in 60:await physics_frame
		if not check(binding.native.field("movable:%d"%id,"state_0x55",0)==1,"RealE opens leaf%d"%id):quit(1);return
	var lane: Array[Vector3] = [Vector3(-330.0, 32.0, -3824.0), Vector3(-450.0, 32.0, -3824.0), Vector3(-510.0, 32.0, -3850.0), Vector3(-512.0, 32.0, -3924.0), Vector3(-514.0, 32.0, -4004.0), Vector3(-514.0, 32.0, -4084.0)]
	for point in lane:
		await push(scene, point, 300)
		if scene.resets != 0 or scene.player.position.y < 20.0 or scene.player.position.distance_to(point) > 20.0:
			break
	var room := PackedVector2Array([Vector2(-570, -4132), Vector2(-458, -4132), Vector2(-458, -4036), Vector2(-570, -4036)])
	if not check(inside(room, scene.player.position) and scene.resets == 0 and scene.player.position.y > 20.0, "the maus door reaches the globe room (at %s resets %d)" % [scene.player.position, scene.resets]):
		quit(1)
		return
	var item := "act2:L10_DC:item46"
	await look(scene.act2_items.aim_point(item))
	await tap(KEY_E)
	check(item in scene.carried_collected, "RealE takes globe46 from the room (at %s)" % scene.player.position)
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("PASS L10 globe room: walls 5503, 5505 and 5514 hold, the maus door takes item 46, resets 0")
	quit(0 if failures == 0 else 1)
