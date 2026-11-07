extends Node
## Colour-texture adapter using each area's own original shade table, not L8's palette.
const Night = preload("res://scripts/lol2/l8_night.gd")
const AREAS := ["L10_DC", "L13_RC", "L16_CA", "L19_BC"]
const CELL := 512.0
var cells: Dictionary = {}
var rows_texture: ImageTexture
var bindings: Array = []
var materials: Array[ShaderMaterial] = []
func configure(area: String, pack: Dictionary) -> void:
	var rows: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/sector_shades/%s.json" % area))
	var image := Image.create(64, 1, false, Image.FORMAT_RGBF)
	for i in 64:
		var r: Array = rows.rows[i]
		image.set_pixel(i, 0, Color(r[0], r[1], r[2]))
	rows_texture = ImageTexture.create_from_image(image)
	for face in pack.faces:
		if face.kind != "floor" or not face.get("sector_light") is Array: continue
		var outline := PackedVector2Array()
		var box := Rect2(float(face.points[0][0]), float(face.points[0][2]), 0, 0)
		var height := 0.0
		for point in face.points:
			var p := Vector2(point[0], point[2])
			outline.append(p); box = box.expand(p); height += float(point[1])
		height /= face.points.size()
		var row := [outline, height, Night.light_of(face.sector_light)]
		for x in range(floori(box.position.x / CELL), floori(box.end.x / CELL) + 1):
			for z in range(floori(box.position.y / CELL), floori(box.end.y / CELL) + 1):
				var key := Vector2i(x,z)
				if not cells.has(key): cells[key] = []
				cells[key].append(row)
func at_point(point: Vector3) -> Vector4:
	var result := Night.FULL_BRIGHT
	var distance := INF
	for row in cells.get(Vector2i(floori(point.x/CELL),floori(point.z/CELL)), []):
		if Geometry2D.is_point_in_polygon(Vector2(point.x,point.z), row[0]) and absf(point.y-float(row[1])) < distance:
			distance = absf(point.y-float(row[1])); result = row[2]
	return result
func face_light(face: Dictionary) -> Color:
	var light: Vector4
	if face.get("sector_light") is Array: light = Night.light_of(face.sector_light)
	else:
		var centre := Vector3.ZERO
		for p in face.points: centre += Vector3(p[0],p[1],p[2])
		light = at_point(centre / face.points.size())
	return Color(light.x,light.y,light.z,light.w)
func convert_material(source: StandardMaterial3D, mode: int, light: Vector4) -> ShaderMaterial:
	var material := Night.material_for(source,mode,light,false)
	material.set_shader_parameter("has_rows",true)
	material.set_shader_parameter("shade_rows",rows_texture)
	materials.append(material)
	bindings.append([source, material, source.albedo_texture])
	return material
func apply(host: Node3D) -> void:
	for mesh in host.static_meshes:
		if mesh.mesh == null or mesh.mesh.get_surface_count()==0: continue
		var source: Material = mesh.mesh.surface_get_material(0)
		if source is StandardMaterial3D: mesh.material_override = convert_material(source,Night.SOURCE_CUSTOM0,Night.FULL_BRIGHT)
	for child in host.get_children():
		if child is MultiMeshInstance3D and str(child.name).begins_with("MapProps"):
			var source: Material = child.multimesh.mesh.material
			if source is StandardMaterial3D: child.multimesh.mesh.material = convert_material(source,Night.SOURCE_INSTANCE,Night.FULL_BRIGHT)
	if host.progression != null:
		for hinge in host.progression.hinges.values():
			var light := at_point(hinge.position)
			for mesh in hinge.get_children():
				if mesh is MeshInstance3D and mesh.material_override is StandardMaterial3D:
					mesh.material_override = convert_material(mesh.material_override,Night.SOURCE_UNIFORM,light)
func set_enabled(value: bool) -> void:
	for material in materials: material.set_shader_parameter("night_enabled",value)
func _process(_delta: float) -> void:
	# Keep source surface animation alive when the drawn material is a shader override.
	for binding in bindings:
		if binding[0].albedo_texture != binding[2]:
			binding[2] = binding[0].albedo_texture
			binding[1].set_shader_parameter("albedo",binding[2])
