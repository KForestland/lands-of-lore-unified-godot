extends SceneTree
var failures := 0
const PACK := "res://assets/lol2/generated/dragon_level/area.json"
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: " + message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACK))
	check(data.source.sha256 == "700300d0cdf7df0af9471f3476c4e6ba473a603fa89e3a6e1855037d70be09c7", "archive pin")
	var kinds := {}
	var walls := {}
	for face in data.faces:
		kinds[face.kind] = int(kinds.get(face.kind, 0)) + 1
		check(data.materials.has(str(face.get("material", ""))), "visible face has a texture")
		if face.get("source_wall", false): walls[int(face.wall_record)] = true
	check(int(kinds.get("floor",0)) == 6782 and int(kinds.get("ceiling",0)) == 6811, "subdivision-aware floors and ceilings")
	check(walls.size() == 12006, "all supported source walls, no duplicate record")
	check(data.props.size() == 2627, "2615 native props plus 12 initial attached props")
	var scene = load("res://scenes/lol2/dragon_level.tscn").instantiate()
	root.add_child(scene)
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	check(scene.ready_for_review, "scene ready")
	check(not scene.huline_content, "no Jungle progression")
	# PT-L9-WALLS (owner playtest 2026-11-02; astra d5c1b0b): native bit0 region walls attached, Spark fields open them.
	check(scene.region_blockers_enabled and scene.preview_blockers > 0, "native L9 region walls attached (%s)" % scene.preview_blockers)
	check(scene.prop_instances == 2627 and scene.prop_placements.size() == 2627, "every exported initial prop hosted once")
	check(scene.preview_assemblies != null and scene.preview_assemblies.solid_bodies.size() > 0, "native assembly boxes attached")
	print("L9 solid bodies=", scene.preview_assemblies.solid_bodies.size())
	check(scene.player.position.distance_to(Vector3(3607,-12,-8471)) < 5.0, "native selector0 preview position")
	for face in data.faces:
		if face.get("source_wall", false): check(not scene.include_collision_face(face), "walls drawn only")
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(scene.player.position + Vector3.UP * 150.0, scene.player.position + Vector3.DOWN * 150.0, scene.RAY_MASK, [scene.player.get_rid()])
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(ray)
	check(not hit.is_empty(), "native arrival has terrain contact")
	var origin: Vector3 = scene.player.position
	for i in 60:
		await physics_frame
	check(scene.player.position.y > origin.y - 50.0, "arrival remains supported under gravity")
	# Exercise the actual grounded mover at each native arrival, without flying or fabricated spawn locations.
	scene.set_physics_process(false)
	for arrival in data.arrivals:
		scene.player.position = Vector3(arrival.position[0], arrival.position[1], arrival.position[2])
		scene.player.velocity = Vector3.ZERO
		for i in 30:
			scene.move_grounded(Vector3.ZERO, 1.0/60.0, false)
			await physics_frame
		var before: Vector3 = scene.player.position
		for i in 45:
			scene.move_grounded(Vector3.FORWARD, 1.0/60.0, false)
			await physics_frame
		print("L9 arrival ", arrival.selector, " walk displacement=", scene.player.position - before)
		check(scene.player.position.is_finite() and scene.player.position.y > before.y - 100.0, "arrival walk remains supported: " + str(arrival.selector))
	scene.queue_free()
	await process_frame
	print("L9 MAP ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
