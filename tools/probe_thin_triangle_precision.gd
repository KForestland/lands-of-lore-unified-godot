extends SceneTree
## Isolate known thin-triangle ray misses at source coordinates and near origin.
var map_root := "/home/bob/lol2_out/all_maps_20260922"

func _initialize() -> void:
	call_deferred("run")

func vec(p: Array) -> Vector3:
	return Vector3(p[0], p[1], p[2])

func probe(points: Array[Vector3], translation: Vector3, add_surface: bool) -> Dictionary:
	var body := StaticBody3D.new()
	var vertices := PackedVector3Array()
	for p in points: vertices.append(p-translation)
	if add_surface:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(vertices)
		shape.backface_collision = true
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
	root.add_child(body)
	await physics_frame
	await physics_frame
	var center := (vertices[0]+vertices[1]+vertices[2])/3.0
	var normal := (vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
	var ray := PhysicsRayQueryParameters3D.create(center+normal*0.25, center-normal*0.25)
	ray.hit_back_faces = true
	var hit := body.get_world_3d().direct_space_state.intersect_ray(ray)
	var result := {"hit": not hit.is_empty(), "center": [center.x, center.y, center.z],
		"translation": [translation.x, translation.y, translation.z]}
	root.remove_child(body)
	body.free()
	return result

func run() -> void:
	var output_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output_path = arg.trim_prefix("--report=")
		if arg.begins_with("--map-root="): map_root = arg.trim_prefix("--map-root=")
	if output_path.is_empty():
		push_error("--report required")
		quit(2)
		return
	var results: Array = []
	for specification in [["L1_DC", 1781, "floor", 0], ["L16_CA", 7734, "floor", 1], ["L16_CA", 7734, "ceiling", 1]]:
		var review_path: String = map_root.path_join(specification[0]).path_join("review.json")
		var review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(review_path))
		var matched := false
		for face in review.faces:
			if int(face.get("region", -1)) != specification[1] or face.kind != specification[2]: continue
			matched = true
			var points: Array[Vector3] = [vec(face.points[0]), vec(face.points[specification[3]+1]), vec(face.points[specification[3]+2])]
			var original: Dictionary = await probe(points, Vector3.ZERO, true)
			var centered: Dictionary = await probe(points, points[0], true)
			results.append({"area": specification[0], "region": specification[1], "kind": specification[2],
				"review_sha256": FileAccess.get_sha256(review_path), "original": original, "locally_centered": centered})
			break
		if not matched:
			push_error("Source case missing")
			quit(1)
			return
	var control: Array[Vector3] = [Vector3(0, 0, 0), Vector3(64, 0, 0), Vector3(0, 0, 64)]
	var positive: Dictionary = await probe(control, Vector3.ZERO, true)
	var negative: Dictionary = await probe(control, Vector3.ZERO, false)
	var report := {"scope": "Same source float vertices in isolated triangle collision, translated before centroid arithmetic. No source meshes modified.",
		"results": results, "positive_control": positive, "negative_control": negative}
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(report))
	quit(0 if positive.hit and not negative.hit else 1)
