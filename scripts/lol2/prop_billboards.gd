## Batched scenery props for the Act 2/3 map hosts (the darker_jungle.gd recipe, 2026-10-30): one MultiMesh per
## (material, box, flip) of fixed-Y billboard quads at every pack row's native placement, first frame only (no frame
## rate is proven for these levels, as for the Hive/Jungle scenery). Native 129AC8 frame setup: flag 0x40 reverses the
## columns, 0x80 the rows (hive_jungle_scenery.gd). Returns {batches, instances, placements}; placements maps
## record -> [MultiMesh, index, position]. Placement rows carry their record; attached type-1 children
## (map_primitive_geometry) carry none and are keyed by their pack row below zero (-1 - row).

static func batch(host: Node3D, data: Dictionary, geometry_file: String, prefix: String) -> Dictionary:
	var prop_materials: Dictionary = {}
	var groups: Dictionary = {}
	var placements: Dictionary = {}
	for row in data.props.size():
		var prop: Dictionary = data.props[row]
		var flip := int(prop.get("frame_flags", 0)) & 0xC0
		var key := "%s|%s|%s|%s|%s|%d" % [prop.material, prop.left, prop.right, prop.bottom, prop.top, flip]
		if not groups.has(key): groups[key] = []
		groups[key].append([prop, int(prop.record) if prop.has("record") else -1 - row])
	var keys := groups.keys()
	keys.sort()
	var batches := 0
	var instances := 0
	for key in keys:
		var rows: Array = groups[key]
		var first: Dictionary = rows[0][0]
		var material_key: String = first.material
		var flip := int(first.get("frame_flags", 0)) & 0xC0
		var material_id := "%s|%d" % [material_key, flip]
		if not prop_materials.has(material_id):
			var material := StandardMaterial3D.new()
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(geometry_file.get_base_dir()+"/"+data.materials[material_key]))
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			material.uv1_scale = Vector3(-1.0 if flip & 0x40 else 1.0, -1.0 if flip & 0x80 else 1.0, 1.0)
			material.uv1_offset = Vector3(1.0 if flip & 0x40 else 0.0, 1.0 if flip & 0x80 else 0.0, 0.0)
			prop_materials[material_id] = material
		var quad := QuadMesh.new()
		quad.size = Vector2(float(first.right) - float(first.left), float(first.top) - float(first.bottom))
		quad.center_offset = Vector3((float(first.left) + float(first.right)) / 2.0, (float(first.bottom) + float(first.top)) / 2.0, 0)
		quad.material = prop_materials[material_id]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = quad
		multi.use_custom_data = true
		multi.instance_count = rows.size()
		for i in rows.size():
			var prop: Dictionary = rows[i][0]
			var at := Vector3(prop.position[0], prop.position[1], prop.position[2])
			multi.set_instance_transform(i, Transform3D(Basis(), at))
			# The row's native sector light ([ambient, fade start, span, 128]; map_lighting.py) as INSTANCE_CUSTOM for a lit host.
			var light: Variant = prop.get("sector_light")
			multi.set_instance_custom_data(i, Color(float(light[0]), float(light[1]), float(light[2]), float(light[3])) if light is Array and (light as Array).size() >= 4 else Color(63, 9999, 9999, 128))
			placements[int(rows[i][1])] = [multi, i, at]
		var node := MultiMeshInstance3D.new()
		node.name = "%s_%d" % [prefix, batches]
		node.multimesh = multi
		host.add_child(node)
		batches += 1
		instances += rows.size()
	return {"batches": batches, "instances": instances, "placements": placements}
