extends Node3D
## Original static gallery assemblies159–164; no invented motion or interaction.
const ROOT := "res://assets/lol2/generated/museum_portraits/"
func _ready() -> void:
	name = "MuseumPortraits"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "portraits.json"))
	var surfaces: Dictionary = {}
	for face in data.faces:
		var key: String = face.material
		if not surfaces.has(key):
			var material := StandardMaterial3D.new()
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT + data.materials[key]))
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			# Two source portraits have zero thickness: front/back share a plane.
			# Their original opposite windings select the visible side without z-fighting.
			material.cull_mode = BaseMaterial3D.CULL_BACK
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(material)
			surfaces[key] = surface
		var surface: SurfaceTool = surfaces[key]
		for i in [0,1,2,0,2,3]:
			surface.set_uv(Vector2(face.uv[i][0],face.uv[i][1]))
			surface.add_vertex(Vector3(face.points[i][0],face.points[i][1],face.points[i][2]))
	for surface in surfaces.values():
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		add_child(mesh)
