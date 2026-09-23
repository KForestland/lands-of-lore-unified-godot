extends SceneTree
## Probe each nondegenerate floor/ceiling fan triangle in saved structural collision.
## This checks sampled surface presence, not walkability or capsule movement.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var map_root := "/home/bob/lol2_out/all_maps_20260922"
	var report_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map-root="): map_root = arg.trim_prefix("--map-root=")
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	var index_path := map_root.path_join("index.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	var rows: Array = []
	var failures := 0
	var total_hits := 0
	for entry in index.areas:
		var area: String = entry.id
		var area_dir := map_root.path_join(area)
		var review_path := area_dir.path_join("review.json")
		var scene_path := area_dir.path_join("map.scn")
		var review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(review_path))
		var packed := load(scene_path) as PackedScene
		if packed == null:
			push_error("Cannot load " + scene_path)
			quit(1)
			return
		var scene := packed.instantiate() as Node3D
		root.add_child(scene)
		await physics_frame
		await physics_frame
		var space := scene.get_world_3d().direct_space_state
		var row := {"area": area, "hits": 0, "degenerate_triangles": 0, "misses": [],
			"review_sha256": FileAccess.get_sha256(review_path),
			"scene_sha256": FileAccess.get_sha256(scene_path)}
		for face in review.faces:
			if face.kind != "floor" and face.kind != "ceiling": continue
			var points: Array = face.points
			var a := vec(points[0])
			for i in range(1, points.size() - 1):
				var b := vec(points[i])
				var c := vec(points[i + 1])
				var cross := (b-a).cross(c-a)
				if cross.length() < 0.000001:
					row.degenerate_triangles += 1
					continue
				var center := (a+b+c)/3.0
				var normal := cross.normalized()
				var found := false
				for sign_value in [1.0, -1.0]:
					var query := PhysicsRayQueryParameters3D.create(center+normal*0.25*sign_value, center-normal*0.25*sign_value)
					query.hit_back_faces = true
					var hit := space.intersect_ray(query)
					if not hit.is_empty() and (hit.position as Vector3).distance_to(center) < 0.02 and (hit.collider as Node).name == "StructuralCollision":
						found = true
						break
				if found:
					row.hits += 1
					total_hits += 1
				else:
					var longest := maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
					var polygon_center := Vector3.ZERO
					for point in points: polygon_center += vec(point)
					polygon_center /= points.size()
					var nearby := center + (polygon_center-center).normalized()*0.01
					var nearby_query := PhysicsRayQueryParameters3D.create(nearby+normal*0.25, nearby-normal*0.25)
					nearby_query.hit_back_faces = true
					var nearby_hit := space.intersect_ray(nearby_query)
					row.misses.append({"region": face.region, "kind": face.kind, "triangle": i-1,
						"position": [center.x, center.y, center.z], "minimum_altitude": cross.length()/longest,
						"nearby_probe_offset": 0.01, "nearby_structural_hit": not nearby_hit.is_empty() and (nearby_hit.collider as Node).name == "StructuralCollision"})
		failures += row.misses.size()
		rows.append(row)
		print("%s: %d hits, %d misses, %d degenerate triangles" % [area, row.hits, row.misses.size(), row.degenerate_triangles])
		root.remove_child(scene)
		scene.free()
	var report := {"scope": "Bidirectional normal rays at every exported floor/ceiling fan triangle centroid. No traversal or original-fidelity claim.",
		"index_sha256": FileAccess.get_sha256(index_path), "areas": rows, "hits": total_hits, "misses": failures}
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write " + report_path)
			quit(1)
			return
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	print("Surface collision: %d hits, %d misses" % [total_hits, failures])
	quit(0 if failures == 0 and total_hits > 0 else 1)

func vec(p: Array) -> Vector3:
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
