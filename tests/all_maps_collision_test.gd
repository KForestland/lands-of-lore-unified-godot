extends SceneTree
## Headless smoke for modern exported structural collision only.
## Each index area's map.scn must load with a StaticBody3D named
## StructuralCollision whose ConcavePolygonShape3D holds finite, nonempty
## triangles and is the only collision body (props and movables stay out).
## Representative points come from the review helper's component groups and
## _component_region_preview. The review scene has no collision and is not
## in the tree while the saved scene is, so visible and physics geometry
## are never both present. A downward ray from each viewable preview to
## below bounds_min.y - 16 either hits or is an unresolved miss. Groups
## whose preview is null are skipped nonpositive groups, not hits and not
## exceptions. Rays are not a traversal test and not a capsule test.
## Nothing here marks an area ready.

const Review = preload("res://scripts/lol2/all_maps_review.gd")
const EXPECTED_AREAS := 15

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var map_root: String = Review.DEFAULT_MAP_ROOT
	var report_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map-root="):
			map_root = argument.trim_prefix("--map-root=")
		elif argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
	var index_path := map_root.path_join("index.json")
	if not FileAccess.file_exists(index_path):
		push_error("All-maps collision smoke: no index at " + index_path)
		quit(1)
		return
	var index_data = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if typeof(index_data) != TYPE_DICTIONARY or not index_data.has("areas"):
		push_error("All-maps collision smoke: malformed index at " + index_path)
		quit(1)
		return
	var areas: Array = index_data["areas"]
	if areas.size() != EXPECTED_AREAS:
		push_error("All-maps collision smoke: expected %d areas, index has %d" % [EXPECTED_AREAS, areas.size()])
		quit(1)
		return
	var review = Review.new()
	review.map_root = map_root
	review.set_process(false)
	review.set_process_input(false)
	review.set_process_unhandled_input(false)
	root.add_child(review)
	await process_frame
	review.set_process(false)
	review.set_process_input(false)
	review.set_process_unhandled_input(false)
	var hits := 0
	var misses := 0
	var skipped_nonpositive := 0
	var area_rows: Array = []
	var miss_groups: Array = []
	var failures := 0
	for i in range(areas.size()):
		var entry: Dictionary = areas[i]
		var area_id: String = str(entry.get("id", ""))
		var scene_path := map_root.path_join(area_id).path_join("map.scn")
		review._select_area(i)
		await process_frame
		var row := {
			"area_id": area_id,
			"hits": 0,
			"misses": 0,
			"skipped_nonpositive": 0,
			"triangles": 0,
			"status": "fail",
		}
		var reason := ""
		if review.current_area.is_empty():
			reason = "review area failed to load"
		elif not review.has_bounds:
			reason = "review area has no bounds"
		elif not FileAccess.file_exists(scene_path):
			reason = "saved scene missing: " + scene_path
		else:
			var area_dir: String = review.current_area_dir
			var inventory_path := area_dir.path_join("review_inventory.json")
			if area_dir.is_empty() or not FileAccess.file_exists(inventory_path):
				reason = "review area directory or component inventory missing"
		if reason.is_empty():
			var packed = load(scene_path)
			if packed == null or not (packed is PackedScene):
				reason = "saved scene failed to load: " + scene_path
			else:
				root.remove_child(review)
				var loaded: Node3D = packed.instantiate() as Node3D
				if loaded == null:
					reason = "saved scene failed to instantiate: " + scene_path
					root.add_child(review)
				else:
					root.add_child(loaded)
					await physics_frame
					await physics_frame
					var structural := _structural_problem(loaded, area_id)
					reason = str(structural.get("reason", ""))
					row["triangles"] = int(structural.get("triangles", 0))
					if reason.is_empty():
						var space: PhysicsDirectSpaceState3D = loaded.get_world_3d().direct_space_state
						if space == null:
							reason = "saved scene has no physics space"
						else:
							var floor_y: float = review.bounds_min.y - 16.0
							var groups: Array = review.component_groups
							if groups.is_empty():
								reason = "no component groups"
							for group_index in range(groups.size()):
								var group: Dictionary = groups[group_index]
								var preview = review._component_region_preview(group)
								if preview == null:
									row["skipped_nonpositive"] = int(row["skipped_nonpositive"]) + 1
									skipped_nonpositive += 1
									continue
								var origin: Vector3 = preview
								var query := PhysicsRayQueryParameters3D.create(origin, Vector3(origin.x, floor_y, origin.z))
								query.hit_back_faces = true
								var hit: Dictionary = space.intersect_ray(query)
								var component_index := int(group.get("component_index", group_index))
								if hit.is_empty():
									row["misses"] = int(row["misses"]) + 1
									misses += 1
									var miss := {
										"area_id": area_id,
										"group": component_index,
										"position": [origin.x, origin.y, origin.z],
									}
									miss_groups.append(miss)
									print("MISS area %s group %d at %s" % [area_id, component_index, origin])
								else:
									row["hits"] = int(row["hits"]) + 1
									hits += 1
							if int(row["misses"]) > 0 and reason.is_empty():
								reason = "unresolved structural ray miss"
					root.remove_child(loaded)
					loaded.free()
					root.add_child(review)
		if reason.is_empty() and int(row["hits"]) + int(row["misses"]) == 0:
			reason = "no viewable component group"
		if reason.is_empty():
			row["status"] = "pass"
		else:
			failures += 1
			row["reason"] = reason
		print("area %s hits %d misses %d skipped_nonpositive %d triangles %d%s" % [
			area_id, int(row["hits"]), int(row["misses"]), int(row["skipped_nonpositive"]), int(row["triangles"]),
			"" if reason.is_empty() else " unresolved: " + reason])
		area_rows.append(row)
	if review.get_parent() == root:
		root.remove_child(review)
	review.free()
	var report := {
		"scope": "Vertical PhysicsRayQueryParameters3D probes from component preview positions into exported StructuralCollision. Not traversal. Not capsule collision. A miss is unresolved. Maps are not marked ready.",
		"map_root": map_root,
		"areas": areas.size(),
		"hits": hits,
		"misses": misses,
		"skipped_nonpositive_groups": skipped_nonpositive,
		"miss_groups": miss_groups,
		"area_results": area_rows,
	}
	if not report_path.is_empty():
		var report_dir := report_path.get_base_dir()
		if not report_dir.is_empty():
			DirAccess.make_dir_recursive_absolute(report_dir)
		var output := FileAccess.open(report_path, FileAccess.WRITE)
		if output == null:
			push_error("All-maps collision smoke: could not write " + report_path)
			failures += 1
		else:
			output.store_string(JSON.stringify(report))
			output.close()
	if failures == 0 and misses == 0:
		print("All-maps collision smoke: PASS (%d areas, %d hits, %d skipped_nonpositive)" % [areas.size(), hits, skipped_nonpositive])
		quit(0)
	else:
		print("All-maps collision smoke: FAIL (%d/%d areas, %d misses)" % [failures, areas.size(), misses])
		quit(1)

## StructuralCollision only. Props and any other collision body fail the area.
func _structural_problem(loaded: Node, expected_area_id: String) -> Dictionary:
	if not loaded.has_meta("area_id") or str(loaded.get_meta("area_id")) != expected_area_id:
		return {"reason": "area_id metadata missing or mismatched", "triangles": 0}
	if not loaded.has_meta("source"):
		return {"reason": "source metadata missing", "triangles": 0}
	var source: Dictionary = loaded.get_meta("source")
	var source_area: String = str(source.get("area_id", ""))
	if source_area != expected_area_id:
		return {"reason": "source area_id missing or mismatched", "triangles": 0}
	var bodies := loaded.find_children("*", "CollisionObject3D", true, false)
	if bodies.size() != 1 or bodies[0].name != "StructuralCollision" or not (bodies[0] is StaticBody3D):
		return {"reason": "collision is not exactly one StructuralCollision StaticBody3D (props or movables included)", "triangles": 0}
	var body := bodies[0] as StaticBody3D
	if body.get_parent() != loaded:
		return {"reason": "StructuralCollision is not a direct child of the area", "triangles": 0}
	var shape_nodes := body.find_children("*", "CollisionShape3D", true, false)
	if shape_nodes.size() != 1:
		return {"reason": "StructuralCollision shape count is %d" % shape_nodes.size(), "triangles": 0}
	var shape := (shape_nodes[0] as CollisionShape3D).shape
	if shape == null or not (shape is ConcavePolygonShape3D):
		return {"reason": "StructuralCollision is not a ConcavePolygonShape3D", "triangles": 0}
	var faces := (shape as ConcavePolygonShape3D).get_faces()
	if faces.is_empty() or faces.size() % 3 != 0:
		return {"reason": "StructuralCollision triangles missing or incomplete", "triangles": 0}
	for vertex in faces:
		if not (is_finite(vertex.x) and is_finite(vertex.y) and is_finite(vertex.z)):
			return {"reason": "StructuralCollision has a non-finite vertex", "triangles": 0}
	return {"reason": "", "triangles": faces.size() / 3}
