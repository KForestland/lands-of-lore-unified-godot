extends Node3D
## Museum control 181 Case: always-visible type0 children 26..34 (stone pedestal, posts, ring, cap).
## The sword (child 35) and empty mode-1 child 36 are not drawn here. The source has no glass face.
## Contact is the template 22x22x70 volume from 0x5BE5D/0x5CF44 on layer 1. The rendered faces are a
## separate ray-only occluder, so an item ray passes the open sides but not the stone.
const ROOT := "res://assets/lol2/generated/museum_broken_case/"
var catalog: Dictionary
var contact: StaticBody3D
var visibility: StaticBody3D
var meshes: Array[MeshInstance3D] = []
var face_count := 0

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "case.json"))
	if catalog.id != "museum:control181:case" or int(catalog.control) != 181 or int(catalog.template) != 9:
		push_error("Case catalog changed")
		return
	var groups: Dictionary = {}
	var occluder := PackedVector3Array()
	for face in catalog.faces:
		var key := str(face.material)
		if not groups.has(key):
			var mat := StandardMaterial3D.new()
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT + str(catalog.materials[key])))
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(mat)
			groups[key] = surface
		var surface: SurfaceTool = groups[key]
		for i in [0, 1, 2, 0, 2, 3]:
			var p: Array = face.points[i]
			var vertex := Vector3(float(p[0]), float(p[1]), float(p[2]))
			surface.set_uv(Vector2(float(face.uv[i][0]), float(face.uv[i][1])))
			surface.add_vertex(vertex)
			occluder.append(vertex)
		face_count += 1
	for key in groups.keys():
		var surface: SurfaceTool = groups[key]
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name = "Material_%s" % key
		mesh.mesh = surface.commit()
		add_child(mesh)
		meshes.append(mesh)
	contact = StaticBody3D.new()
	contact.name = "Contact"
	contact.collision_layer = int(catalog.contact.collision_layer)
	contact.collision_mask = int(catalog.contact.collision_mask)
	var box := BoxShape3D.new()
	var size: Array = catalog.contact.size
	box.size = Vector3(float(size[0]), float(size[1]), float(size[2]))
	var box_shape := CollisionShape3D.new()
	box_shape.shape = box
	var center: Array = catalog.contact.center
	box_shape.position = Vector3(float(center[0]), float(center[1]), float(center[2]))
	contact.add_child(box_shape)
	add_child(contact)
	visibility = StaticBody3D.new()
	visibility.name = "Visibility"
	visibility.collision_layer = int(catalog.visibility.collision_layer)
	visibility.collision_mask = int(catalog.visibility.collision_mask)
	var faces := ConcavePolygonShape3D.new()
	faces.backface_collision = true
	faces.set_faces(occluder)
	var face_shape := CollisionShape3D.new()
	face_shape.shape = faces
	visibility.add_child(face_shape)
	add_child(visibility)

## RIDs an item ray toward something inside the case should exclude. The contact volume encloses it.
func interaction_exclude() -> Array[RID]:
	var rids: Array[RID] = []
	if contact != null:
		rids.append(contact.get_rid())
	return rids

## Native-order anchor of child 35 (height 15+38). The control181 export anchor differs; see docs.
func sword_anchor() -> Vector3:
	var p: Array = catalog.sword_anchor.native_order_position
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
