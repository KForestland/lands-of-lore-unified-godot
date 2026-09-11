extends "res://scripts/lol2/special_cave_review.gd"

const PLACED_ROOT := "res://assets/lol2/generated/special_prop_review/"
var placed_props: Array
var native_translation := Vector3.ZERO
var selected_record := 1057
var placed_instances: Array[MeshInstance3D] = []

func _remap_path() -> String:
	return PLACED_ROOT + "remap.png"

func _capture_directory() -> String:
	return _capture_path("special_placed_%d") % selected_record

func _configure_review() -> void:
	placed_props = JSON.parse_string(FileAccess.get_file_as_string(PLACED_ROOT + "props.json")).props
	var anchor: Dictionary = {}
	for face in data.faces:
		if int(face.region) == int(fixtures[selected].regions[0]):
			anchor = face
			break
	native_translation = point(fixtures[selected].faces[0][0]) - point(anchor.points[0]) * 64.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--special-record="):
			selected_record = int(argument.trim_prefix("--special-record="))
	var found := false
	for prop in placed_props:
		if int(prop.record) == selected_record:
			var center := point(prop.position_native) + native_translation + Vector3((prop.left + prop.right) / 2, (prop.bottom + prop.top) / 2, 0)
			# Start inside the recorded floor region: the generic110-unit
			# inspection orbit can cross walls in these narrow passages.
			var floor_center := Vector3.ZERO
			for face in data.faces:
				if int(face.region) == int(prop.region):
					for vertex in face.points: floor_center += point(vertex) * 64.0
					floor_center /= face.points.size()
					break
			var position := floor_center + native_translation
			position.y = center.y + 8.0
			player.rotation = Vector3.ZERO
			player.global_position = position - Vector3(0, 24, 0)
			camera.look_at(center, Vector3.UP)
			found = true
	if not found:
		push_error("Special record must be 1051, 1057 or 1058")
		get_tree().quit(1)
		return
	get_window().title = "Recovered special props — inspect record %d · fixed camera" % selected_record
	# Fixed-Y planes are parallel: sort by horizontal camera depth, not
	# distance to center (which would incorrectly include their heights).
	placed_props.sort_custom(func(a, b):
		var direction := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z)
		return direction.dot(point(a.position_native)) < direction.dot(point(b.position_native)))

func _build_review() -> void:
	var previous: Texture2D = index_view.get_texture()
	var order: Array = []
	for i in range(placed_props.size()):
		var prop: Dictionary = placed_props[i]
		var layer := 8 << i
		var material := _indexed_material(PLACED_ROOT + "sprite_%d.png" % int(prop.descriptor))
		material.set_shader_parameter("sprite", true)
		var flags := int(prop.frame_flags) & 0xC0
		material.set_shader_parameter("uv_scale", Vector2(-1.0 if flags & 0x40 else 1.0, -1.0 if flags & 0x80 else 1.0))
		material.set_shader_parameter("uv_offset", Vector2(1.0 if flags & 0x40 else 0.0, 1.0 if flags & 0x80 else 0.0))
		var quad := QuadMesh.new()
		quad.size = Vector2(prop.right - prop.left, prop.top - prop.bottom)
		quad.center_offset = Vector3((prop.left + prop.right) / 2, (prop.bottom + prop.top) / 2, 0)
		quad.material = material
		var instance := MeshInstance3D.new()
		instance.mesh = quad
		instance.position = point(prop.position_native) + native_translation
		instance.layers = layer
		add_child(instance)
		placed_instances.append(instance)
		_source_view(layer, false)
		var view := _source_view(layer)
		var composite := _compose(previous, view.get_texture())
		previous = composite.get_texture()
		order.append(int(prop.record))
	resolve_surface.material.set_shader_parameter("packed_wall_indices", previous)
	DirAccess.make_dir_recursive_absolute(_capture_directory())
	var file := FileAccess.open(_capture_directory() + "/placement_view.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"selected_record": selected_record, "far_to_near_records": order, "translation": [native_translation.x, native_translation.y, native_translation.z], "scope": "Recovered three single-state placements; fixed-Y preview, fixed inspection camera, original draw order not claimed."}, "  "))
	print("Recovered special placement review: ", order)
