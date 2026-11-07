extends Node3D
## Original static rubble-room blocks 64-76 and 95 (regions 329-335); no source use record, so no motion or interaction.
## Block179 stays with its control96 owner.
const ROOT := "res://assets/lol2/generated/museum_rubble_blocks/"
static func assets_ready() -> bool:
	return FileAccess.file_exists(ROOT + "blocks.json")
func _ready() -> void:
	name = "MuseumRubbleBlocks"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "blocks.json"))
	var surfaces: Dictionary = {}
	for face in data.faces:
		var key: String = face.material
		if not surfaces.has(key):
			var material := StandardMaterial3D.new()
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT + data.materials[key]))
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
