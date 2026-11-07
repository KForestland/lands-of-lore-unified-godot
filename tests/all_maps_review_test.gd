extends SceneTree
## Headless smoke test: loads every area from the map index and checks
## finite, buildable geometry. A missing/empty index, a missing declared
## material file, an area id mismatch, empty source faces or nonfinite
## input are treated as failures (the export is expected to be real once
## the lead's integration lands). A material id that is simply not
## declared anywhere is an intentional, reported gap, not a failure.

const Review = preload("res://scripts/lol2/all_maps_review.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var map_root := Review.DEFAULT_MAP_ROOT
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map-root="): map_root = argument.trim_prefix("--map-root=")
	var index_path := map_root.path_join("index.json")
	if not FileAccess.file_exists(index_path):
		push_error("All-maps review smoke: no index at " + index_path)
		quit(1)
		return
	var index_data = JSON.parse_string(FileAccess.get_file_as_string(index_path))
	if typeof(index_data) != TYPE_DICTIONARY or not index_data.has("areas"):
		push_error("All-maps review smoke: malformed index at " + index_path)
		quit(1)
		return
	var areas: Array = index_data.areas
	if areas.is_empty():
		push_error("All-maps review smoke: index has no areas at " + index_path)
		quit(1)
		return
	var scene = Review.new()
	scene.map_root = map_root
	root.add_child(scene)
	await process_frame
	var failures := 0
	for i in range(areas.size()):
		var entry: Dictionary = areas[i]
		var label := str(entry.get("id", "?"))
		scene._select_area(i)
		await process_frame
		var reasons: Array[String] = []
		if scene.current_area.is_empty():
			reasons.append("area failed to load or failed validation (see preceding error)")
		else:
			if scene.broken_material_paths.size() > 0:
				reasons.append("%d declared material file(s) failed to load" % scene.broken_material_paths.size())
			if not _geometry_finite(scene):
				reasons.append("non-finite built geometry")
			if scene.face_count == 0:
				reasons.append("no faces built")
			for prop_node in scene.props_root.get_children():
				var source: Dictionary = prop_node.get_meta("source", {})
				if source.has("left") and source.has("top"):
					var expected := Vector2(float(source.right) - float(source.left), float(source.top) - float(source.bottom))
					var hexes: Array = source.get("frame_hexes", [])
					if not hexes.is_empty():
						for animation in scene.animation_states:
							if animation.material != prop_node.mesh.material: continue
							var frame_index := int(animation.get("index", 0))
							if frame_index >= hexes.size(): continue
							var frame := str(hexes[frame_index]).hex_decode()
							var first := str(hexes[0]).hex_decode()
							var state := str(source.get("state_hex", "")).hex_decode()
							if frame.size() == 12 and first.size() == 12 and state.size() == 16:
								expected = Vector2(float(state[14] - frame[5] - frame[7]), float(source.top) + first[6] - frame[6] - frame[8])
							break
					if not prop_node.mesh.size.is_equal_approx(expected):
						reasons.append("prop %s/%s bounds %s differ from source frame %s" % [source.get("record", "attached"), source.get("material", "?"), prop_node.mesh.size, expected])
						break
		# Exported scenes are optional here: --export-scenes may not have been
		# run yet against this map_root. When map.scn exists (including our
		# own synthetic fixtures), it must reload cleanly and self-contained.
		var scene_path := map_root.path_join(label).path_join("map.scn")
		var export_reason := _validate_exported_scene(scene_path, label, scene.cutout_ids)
		if not export_reason.is_empty(): reasons.append(export_reason)
		if reasons.is_empty():
			print("PASS area %s: %d faces, %d skipped triangles, %d unresolved materials (gap, %d faces), %d props (%d unresolved material)" % [
				label, scene.face_count, scene.skipped_triangles, scene.missing_material_ids.size(),
				scene.missing_material_faces, scene.prop_count, scene.missing_prop_material_ids.size()])
		else:
			failures += 1
			print("FAIL area %s: %s" % [label, ", ".join(reasons)])
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("All-maps review smoke: PASS (%d areas)" % areas.size())
	else:
		print("All-maps review smoke: FAIL (%d/%d areas failed)" % [failures, areas.size()])
	quit(0 if failures == 0 else 1)

func _geometry_finite(scene) -> bool:
	return _node_geometry_finite(scene.geometry_root)

func _node_geometry_finite(geometry: Node) -> bool:
	for child in geometry.get_children():
		if not (child is MeshInstance3D): continue
		var mesh: Mesh = child.mesh
		if mesh == null or mesh.get_surface_count() == 0: continue
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			if not (is_finite(vertex.x) and is_finite(vertex.y) and is_finite(vertex.z)): return false
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for uv in uvs:
			if not (is_finite(uv.x) and is_finite(uv.y)): return false
	return true

## Reloads a --export-scenes output in isolation (nothing else in this test
## touches disk-saved scenes) and checks it is a self-contained artifact:
## the right area id, non-empty finite geometry, and textures embedded
## rather than pointing back at the export's source PNG files.
func _validate_exported_scene(scene_path: String, expected_area_id: String, expected_cutouts: Dictionary) -> String:
	if not FileAccess.file_exists(scene_path): return ""
	var packed = load(scene_path)
	if packed == null or not (packed is PackedScene): return "exported scene failed to load: " + scene_path
	var area = packed.instantiate()
	if area == null: return "exported scene failed to instantiate: " + scene_path
	var reason := ""
	if not area.has_meta("area_id") or str(area.get_meta("area_id")) != expected_area_id:
		reason = "exported scene area_id metadata missing or mismatched"
	elif not area.has_meta("source"):
		reason = "exported scene missing source provenance metadata"
	else:
		var geometry: Node = area.get_node_or_null("Geometry")
		var props: Node = area.get_node_or_null("Props")
		if geometry == null or geometry.get_child_count() == 0:
			reason = "exported scene has no geometry"
		elif not _node_geometry_finite(geometry):
			reason = "exported scene geometry is non-finite"
		elif not _exported_textures_self_contained(geometry, scene_path):
			reason = "exported scene geometry textures are not embedded"
		elif props != null and not _exported_textures_self_contained(props, scene_path):
			reason = "exported scene prop textures are not embedded"
		else:
			var source: Dictionary = area.get_meta("source")
			var captured: Dictionary = source.get("captured_surface_state", {})
			if not captured.is_empty():
				if str(captured.get("region_table_sha256", "")).length() != 64 or str(captured.get("manifest_sha256", "")).length() != 64:
					reason = "exported captured surface state lost its evidence hashes"
				if bool(source.get("ready", false)):
					reason = "captured surface-only variant claims whole-map readiness"
			var videos: Array = source.get("video_placements", [])
			var video_anchors: Node = area.get_node_or_null("VideoPlacements")
			if not videos.is_empty() and (video_anchors == null or video_anchors.get_child_count() != videos.size()):
				reason = "exported scene lost video placement anchors"
			var prepared_pixels := 0
			for video in videos:
				var pixels: Dictionary = video.get("pixel_assets", {})
				if pixels.get("status", "") != "decoded": continue
				prepared_pixels += 1
				if pixels.get("source_sha256", "") != video.get("sha256", ""):
					reason = "exported video pixels refer to a different source"
				if pixels.get("alpha", "") == "unresolved" and not bool(video.get("visual_contract", {}).get("visual_binding_pending", false)):
					reason = "exported video claims a resolved visual binding despite unknown alpha"
				var review_directory := str(source.get("review_file", "")).get_base_dir()
				for page in pixels.get("index_pages", []) + pixels.get("rgb_pages", []):
					if not FileAccess.file_exists(review_directory.path_join(str(page))):
						reason = "exported video atlas path does not exist"
			if prepared_pixels != int(source.get("coverage", {}).get("video_pixels_prepared", 0)):
				reason = "exported scene lost prepared video pixel metadata"
			if source.get("environment", {}).get("panorama") is Dictionary:
				var environment_node := area.get_node_or_null("Environment") as WorldEnvironment
				if environment_node == null or environment_node.environment == null or environment_node.environment.sky == null:
					reason = "exported scene lost its source panorama"
				else:
					var sky_material := environment_node.environment.sky.sky_material as ShaderMaterial
					var panorama := sky_material.get_shader_parameter("panorama") as Texture2D if sky_material != null else null
					if panorama == null or panorama.get_width() != 1280 or panorama.get_height() != 300:
						reason = "exported panorama missing or wrong source dimensions"
					elif not panorama.resource_path.is_empty() and not panorama.resource_path.begins_with(scene_path + "::"):
						reason = "exported panorama texture is not embedded"
			if bool(source.get("ready", false)) and not bool(source.get("coverage", {}).get("ready_for_content", false)):
				reason = "exported scene claims readiness without completed source coverage"
			var unresolved: Array = source.get("unresolved_materials", [])
			var emulated_faces := 0
			for child in geometry.get_children():
				var face_metadata: Array = child.get_meta("region_faces", [])
				for face in face_metadata:
					if face.get("kind", "") != "emulated_boundary": continue
					emulated_faces += 1
					if not child.get_meta("emulated_boundary", false) or child.get_meta("native_verified", true) or face.get("native_verified", true):
						reason = "exported emulated boundary lost its approximation metadata"
				var movable: Dictionary = child.get_meta("movable", {})
				if not movable.is_empty() and (int(movable.get("child_mask", 1)) & 1) == 0 and child.visible:
					reason = "exported later-state mechanism became visible at startup"
					break
				if not child.has_meta("material_id"): continue
				var material_id: String = str(child.get_meta("material_id"))
				if material_id in unresolved: continue
				var material: Material = child.mesh.surface_get_material(0) if child.mesh != null and child.mesh.get_surface_count() > 0 else null
				var has_image := (material is StandardMaterial3D and material.albedo_texture != null) or (material is ShaderMaterial and material.get_shader_parameter("indices") is Texture2D and material.get_shader_parameter("palette") is Texture2D and material.get_shader_parameter("shade_table") is Texture2D)
				if not has_image:
					reason = "exported scene is missing an expected material image for '%s'" % material_id
					break
				var has_cutout: bool = (material is StandardMaterial3D and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR) or (material is ShaderMaterial and material.get_shader_parameter("cutout") == true)
				if expected_cutouts.has(material_id) and not has_cutout:
					reason = "exported scene lost cutout transparency for material %s" % material_id
					break
			if emulated_faces != int(source.get("coverage", {}).get("emulated_boundaries", {}).get("emulated_faces", 0)):
				reason = "exported scene lost emulated boundary faces"
			if props != null:
				for child in props.get_children():
					if bool(child.get_meta("source", {}).get("hidden", false)) and child.visible:
						reason = "exported later-state attached scenery became visible at startup"
						break
	var light = area.get_node_or_null("MagicLight")
	if light != null:
		if light.materials.is_empty(): reason = "saved light has no material bindings"
		light.enabled = true
		for material in light.materials:
			if material.get_shader_parameter("magic_light") != true: reason = "saved light did not enable"
		light.enabled = false
		for material in light.materials:
			if material.get_shader_parameter("magic_light") != false: reason = "saved light did not disable"
	area.queue_free()
	return reason

func _exported_textures_self_contained(node: Node, scene_path: String) -> bool:
	for child in node.get_children():
		if not (child is MeshInstance3D) or child.mesh == null: continue
		var mesh: Mesh = child.mesh
		for i in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(i)
			if material is ShaderMaterial:
				for parameter in material.shader.get_shader_uniform_list():
					var value = material.get_shader_parameter(parameter.name)
					if value is Texture2D:
						var path: String = value.resource_path
						if not path.is_empty() and not path.begins_with(scene_path + "::"): return false
			if material is StandardMaterial3D and material.albedo_texture != null:
				var path: String = material.albedo_texture.resource_path
				if not path.is_empty() and not path.begins_with(scene_path + "::"): return false
	return true
