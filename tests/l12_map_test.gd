extends SceneTree
const AREA := "L12_CM"
const ROOT := "res://assets/lol2/generated/"
const RAY_MASK := 1
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: " + message)
func read_json(path: String) -> Variant: return JSON.parse_string(FileAccess.get_file_as_string(path))
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var path := ROOT + "maps/" + AREA + "/area.json"
	var pack: Dictionary = read_json(path)
	var nav: Dictionary = read_json(ROOT + "creature_nav/" + AREA + ".json")
	check(nav.regions.size() == 3644, "region count independently pinned by G93")
	check(nav.source_sha256 == pack.source.sha256, "navigation and map share archive pin")
	check(pack.start_selector == 0, "documented native selector0 preview")
	for face in pack.faces:
		if not face.get("floorless",false): check(pack.materials.has(str(face.get("material",""))), "visible face has a texture")
		if face.has("wall_record"): check(face.get("source_wall",false), "native wall marked visual-only")
	for image in pack.materials.values(): check(FileAccess.file_exists(path.get_base_dir()+"/"+image), "material file present")
	var scene = load("res://scenes/lol2/maps/L12_CM.tscn").instantiate()
	root.add_child(scene)
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	check(scene.ready_for_review and not scene.huline_content, "native map ready without Jungle progression")
	check(scene.prop_instances == pack.props.size() and scene.prop_placements.size() == pack.props.size(), "initial props hosted once")
	check(scene.preview_assemblies != null, "assembly collision owner present")
	check(scene.preview_blockers == 0, "unqualified blocker adapter remains off")
	for face in pack.faces:
		if face.get("source_wall",false): check(not scene.include_collision_face(face), "walls do not collide")
	scene.set_physics_process(false)
	for i in 45:
		scene.move_grounded(Vector3.ZERO, 1.0/60.0, false)
		await physics_frame
	var start: Vector3 = scene.player.position
	var ray := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 80, start + Vector3.DOWN * 150, RAY_MASK, [scene.player.get_rid()])
	check(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "native arrival has terrain contact")
	for direction in [Vector3.FORWARD,Vector3.BACK]:
		for i in 45:
			scene.move_grounded(direction,1.0/60.0,false)
			await physics_frame
		print(AREA," walk displacement=",scene.player.position-start)
		check(scene.player.position.is_finite() and scene.player.position.y > start.y - 100, "grounded walk remains supported")
	var save_path := "user://tests/L12_CM_map.json"
	var saved_position: Vector3 = scene.player.position
	check(scene.quicksave(save_path).is_empty(), "map-specific disk save")
	scene.player.position += Vector3(30,20,30)
	check(scene.quickload(save_path).is_empty(), "map-specific disk load")
	check(scene.player.position.distance_to(saved_position)<0.1,"save restores walked position")
	scene.queue_free()
	await process_frame
	print(AREA," MAP ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
