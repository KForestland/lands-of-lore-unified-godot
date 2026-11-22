extends SceneTree
## Native event/state contract and physical leaf placement; earned player traversal is a separate gate.
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL dark_halls_bookcases: ", message); quit(1)
func blocked(scene: Node3D, row: Dictionary) -> bool:
	var center := Vector3(row.center[0], row.center[1], row.center[2])
	var direction := Vector3(1, 0, 0) if float(row.size[0]) < float(row.size[2]) else Vector3(0, 0, 1)
	var query := PhysicsRayQueryParameters3D.create(center - direction * 20, center + direction * 20, preload("res://scripts/lol2/static_assemblies.gd").SCENERY_LAYER)
	return not scene.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func run() -> void:
	change_scene_to_file("res://scenes/lol2/dark_halls.tscn")
	for i in 1500:
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	var scene: Node3D = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("not ready")
	var shelves: Node3D = scene.bookcases
	await physics_frame
	for row in shelves.source.controls:
		var id := str(int(row.control))
		if not blocked(scene, row): return fail("closed shelf not solid " + id)
		if not shelves.use(id) or not shelves.is_open(id): return fail("native open " + id)
		await physics_frame
		await physics_frame
		if blocked(scene, row): return fail("open shelf blocks original opening " + id)
		if not shelves.use(id): return fail("second use " + id)
		await physics_frame
		if id == "58":
			if shelves.is_open(id) or not blocked(scene, row): return fail("58 must close")
		elif not shelves.is_open(id): return fail("one-way shelf closed " + id)
	# Component reproduction of the real earned58 approach failure; this pose was reached by input.
	scene.set_physics_process(false)
	scene.player.position = Vector3(1825.577, 452.0446, -3601.376)
	scene.camera.look_at(Vector3(1778, 459, -3579))
	await physics_frame
	await physics_frame
	if shelves.aimed() != "58": return fail("Visible oblique58 leaf rejected by its own collision hit")
	var obstruction := StaticBody3D.new()
	obstruction.collision_layer = 1
	var obstruction_shape := CollisionShape3D.new()
	var obstruction_box := BoxShape3D.new()
	obstruction_box.size = Vector3(5, 5, 5)
	obstruction_shape.shape = obstruction_box
	obstruction.add_child(obstruction_shape)
	scene.add_child(obstruction)
	obstruction.global_position = scene.camera.global_position.lerp(Vector3(1778,459,-3579), 0.5)
	await physics_frame
	await physics_frame
	if shelves.aimed() == "58": return fail("Intervening wall admitted")
	obstruction.queue_free()
	await physics_frame
	await physics_frame
	if shelves.aimed() != "58": return fail("Removing obstruction did not restore target")
	var path := "user://tests/dark_halls_bookcases.json"
	if not scene.quicksave(path).is_empty(): return fail("save")
	shelves.use("58")
	var saved: Dictionary = preload("res://scripts/lol2/jungle_save.gd").read_save(path, preload("res://scripts/lol2/dark_halls.gd").FORMAT)
	var error: String = scene.apply_save(saved.state)
	if not error.is_empty() or shelves.is_open("58") or not shelves.is_open("51") or not shelves.is_open("59"): return fail("disk rollback " + error)
	if shelves.validate({"51": 1}).is_empty() or shelves.validate({"57": true}).is_empty(): return fail("invalid save admitted")
	print("PASS dark_halls_bookcases: native use opens51/58/59, physical leaves clear doorway; 58 toggles shut; 51/59 remain open; disk rollback, strict keys; component proof only")
	quit(0)
