extends Node3D
## Isolated geometric collision audit. Does not establish original walkability.
var probes: Array[Dictionary] = []
var skipped := 0
var tested_triangles := 0
var audit_scale := 1.0
func _ready() -> void:
	if "--native-scale" in OS.get_cmdline_user_args(): audit_scale = 64.0
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/original_floors/floors.json"))
	if not data is Dictionary:
		push_error("Original floor data missing")
		get_tree().quit(1)
		return
	var triangles := PackedVector3Array()
	for face in data.faces:
		for indices in [[0, 1, 2], [0, 2, 3]]:
			var a := _point(face.points[indices[0]])
			var b := _point(face.points[indices[1]])
			var c := _point(face.points[indices[2]])
			var normal := (b - a).cross(c - a)
			if normal.length_squared() < 0.0000000001 * pow(audit_scale, 4):
				skipped += 1
				continue
			# Vertical probes require nonzero projected triangle area.
			if absf(normal.y) < 0.0000001 * audit_scale * audit_scale:
				skipped += 1
				continue
			triangles.append_array(PackedVector3Array([a, b, c]))
			tested_triangles += 1
			for weights in [Vector3(1.0/3, 1.0/3, 1.0/3), Vector3(0.6, 0.2, 0.2), Vector3(0.2, 0.6, 0.2), Vector3(0.2, 0.2, 0.6)]:
				probes.append({"region": face.region, "triangle": indices, "weights": [weights.x, weights.y, weights.z], "center": a * weights.x + b * weights.y + c * weights.z})
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(triangles)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var failures: Array = []
	for probe in probes:
		var p: Vector3 = probe.center
		var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.01 * audit_scale, p - Vector3.UP * 0.01 * audit_scale)
		query.hit_back_faces = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			failures.append({"region": probe.region, "triangle": probe.triangle, "weights": probe.weights, "reason": "miss"})
		elif hit.position.distance_to(p) > 0.002 * audit_scale:
			failures.append({"region": probe.region, "triangle": probe.triangle, "weights": probe.weights, "reason": "height mismatch", "error": hit.position.distance_to(p)})
	var empty_query := PhysicsRayQueryParameters3D.create(Vector3(1000, 100, 1000) * audit_scale, Vector3(1000, -100, 1000) * audit_scale)
	var empty_ok := get_world_3d().direct_space_state.intersect_ray(empty_query).is_empty()
	var report := {"audit_scale": audit_scale, "tested_triangles": tested_triangles, "tested_probes": probes.size(), "skipped_degenerate": skipped, "failures": failures, "outside_probe_empty": empty_ok, "scope": "Isolated floor collision at four interior points per triangle. No walls, movement, hazards, opening semantics or native collision parity tested."}
	DirAccess.make_dir_recursive_absolute("res://captures")
	var filename := "floor_collision_native_scale.json" if audit_scale == 64 else "floor_collision_audit.json"
	var output := FileAccess.open("res://captures/" + filename, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print("Floor collision audit: ", probes.size(), " probes, ", failures.size(), " failures; outside empty=", empty_ok, "; degenerate skipped=", skipped)
	get_tree().quit(0 if failures.is_empty() and empty_ok else 1)
func _point(p: Array) -> Vector3:
	return Vector3(p[0], p[1], p[2]) * audit_scale
