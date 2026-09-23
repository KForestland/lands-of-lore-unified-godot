extends SceneTree
## Modern review capsule diagnostics. Never modifies arrivals or map readiness.
## Support is sought beneath each source arrival; candidate capsule sits on that
## support, so this does NOT establish the original meaning of arrival height.

func _initialize() -> void:
	call_deferred("run")

func vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

func coords(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func run() -> void:
	var map_root := "/home/bob/lol2_out/all_maps_20260922"
	var report_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map-root="): map_root = arg.trim_prefix("--map-root=")
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	if report_path.is_empty():
		push_error("--report is required")
		quit(2)
		return
	var index_path := map_root.path_join("index.json")
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	var capsule := CapsuleShape3D.new()
	capsule.radius = 8.0
	capsule.height = 64.0
	var results: Array = []
	var counts := {"arrivals": 0, "supported_clear": 0, "overlapping": 0, "no_support": 0, "steep_support": 0}
	for area in index.areas:
		var area_dir: String = map_root.path_join(str(area.id))
		var review_path := area_dir.path_join("review.json")
		var scene_path := area_dir.path_join("map.scn")
		var review: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(review_path))
		var packed := load(scene_path) as PackedScene
		if packed == null:
			push_error("Missing saved map: " + scene_path)
			quit(1)
			return
		var scene := packed.instantiate() as Node3D
		root.add_child(scene)
		await physics_frame
		await physics_frame
		var space := scene.get_world_3d().direct_space_state
		var rows: Array = []
		for arrival in review.arrivals:
			counts.arrivals += 1
			var position := vector(arrival.position)
			var row := {"index": arrival.index, "selector": arrival.selector,
				"region": arrival.region, "source_position": arrival.position}
			var ray := PhysicsRayQueryParameters3D.create(position+Vector3.UP, position+Vector3.DOWN*256.0)
			ray.hit_back_faces = true
			var hit := space.intersect_ray(ray)
			if hit.is_empty():
				row.status = "no_support_within_probe_range"
				counts.no_support += 1
			elif absf((hit.normal as Vector3).y) < 0.7071:
				row.status = "steep_support"
				row.support_position = coords(hit.position)
				counts.steep_support += 1
			else:
				var support: Vector3 = hit.position
				# A vertical capsule resting on a slope needs additional lift: its
				# lower sphere center must remain radius units from the plane.
				var support_normal: Vector3 = hit.normal
				var slope_lift := capsule.radius*(1.0/absf(support_normal.y)-1.0)
				var center := support + Vector3.UP*(32.1+slope_lift)
				row.support_position = coords(support)
				row.support_normal = coords(support_normal)
				row.slope_clearance_lift = slope_lift
				row.source_height_above_support = position.y-support.y
				row.candidate_capsule_center = coords(center)
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.transform = Transform3D(Basis.IDENTITY, center)
				query.margin = 0.0
				var overlaps := space.intersect_shape(query, 8)
				if not overlaps.is_empty():
					row.status = "candidate_overlaps_structure"
					var contacts: Array = []
					for contact in space.collide_shape(query, 8): contacts.append(coords(contact))
					row.contact_points = contacts
					# Diagnostic alternatives only. No source arrival is relocated,
					# and no shape here is asserted to be a native transformation.
					var alternatives: Array = []
					for parameters in [[6.0, 64.0, 0.0], [4.0, 32.0, 0.0], [8.0, 64.0, 4.0], [8.0, 64.0, 12.0]]:
						var alternative := CapsuleShape3D.new()
						alternative.radius = parameters[0]
						alternative.height = parameters[1]
						var alternative_query := PhysicsShapeQueryParameters3D.new()
						alternative_query.shape = alternative
						var lift: float = alternative.radius*(1.0/absf(support_normal.y)-1.0)
						alternative_query.transform = Transform3D(Basis.IDENTITY, support+Vector3.UP*(alternative.height/2.0+0.1+lift+parameters[2]))
						alternative_query.margin = 0.0
						alternatives.append({"radius": parameters[0], "height": parameters[1], "extra_vertical_offset": parameters[2],
							"clear": space.intersect_shape(alternative_query, 8).is_empty()})
					row.diagnostic_alternatives = alternatives
					counts.overlapping += 1
				else:
					row.status = "supported_candidate_clear"
					counts.supported_clear += 1
					var sweeps: Array = []
					for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
						query.motion = direction*16.0
						var fractions := space.cast_motion(query)
						var endpoint: Vector3 = support+direction*16.0
						var endpoint_ray := PhysicsRayQueryParameters3D.create(endpoint+Vector3.UP*4.0, endpoint+Vector3.DOWN*8.0)
						endpoint_ray.hit_back_faces = true
						var endpoint_hit := space.intersect_ray(endpoint_ray)
						sweeps.append({"direction": coords(direction), "safe_fraction": fractions[0],
							"endpoint_has_nearby_support": not endpoint_hit.is_empty()})
					row.sweeps = sweeps
			rows.append(row)
		results.append({"area": area.id, "arrivals": rows,
			"review_sha256": FileAccess.get_sha256(review_path), "scene_sha256": FileAccess.get_sha256(scene_path)})
		print("%s: %d arrival diagnostics" % [area.id, rows.size()])
		root.remove_child(scene)
		scene.free()
	var report := {"scope": "Assumed modern review capsule, not native actor bounds or a traversal acceptance. No arrivals modified. Closed/low/form-dependent arrivals require interpretation.",
		"capsule_radius": 8, "capsule_height": 64, "support_probe_above": 1, "support_probe_below": 256,
		"movement_sweep_length": 16, "index_sha256": FileAccess.get_sha256(index_path), "counts": counts, "areas": results}
	var output := FileAccess.open(report_path, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write " + report_path)
		quit(1)
		return
	output.store_string(JSON.stringify(report, "  "))
	output.close()
	print(JSON.stringify(counts))
	quit(0)
