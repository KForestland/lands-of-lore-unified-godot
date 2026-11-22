extends Node3D
## OF6. Movables 124 and 125 are template 14, "Maus Door": solid mode-6 boxes, 8 by 50 by 100,
## standing in the only corridor into the room that holds globe 46. The gap they leave is 23 wide.
## A radius-15 body cannot pass while they stay shut. Byte +0x52 is the hinge corner, and the corner
## table immediate 0xA20C has no fixup, so the side is not read. Contact turns each leaf 90 degrees
## about its southwest corner. That is the turn whose arc stays off the east approach and leaves a
## lane north of the opened leaf. The reach includes the leaf's height. The box stands from y 0 to
## y 100, so the catacomb passage under it, around y -118, does not open the leaf. Adapter: the
## native push byte +0x57 is not hosted.
const DOORS: Array[int] = [124, 125]
const OPEN_YAW := -PI * 0.5
const OPEN_SECONDS := 0.25
const REACH := 20.0
var host: Node3D
var leaves: Array[Leaf] = []

class Leaf:
	var pivot: Node3D
	var body: AnimatableBody3D
	var xmin: float
	var xmax: float
	var ymin: float
	var ymax: float
	var zmin: float
	var zmax: float
	var amount: float
	var opening: bool

static func owns(face: Dictionary) -> bool:
	if str(face.get("kind", "")) != "movable": return false
	if str(face.get("placement_kind", "")) != "movable": return false
	var index: Variant = face.get("source_index", -1)
	if not (index is int or index is float): return false
	var id: int = int(index)
	return id == 124 or id == 125

static func attach(map: Node3D) -> Node3D:
	var node: Node3D = (load("res://scripts/lol2/l10_globe_door.gd").new() as Node3D)
	node.host = map
	node.name = "L10GlobeDoor"
	map.add_child(node)
	return node

func _ready() -> void:
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
	var faces: Array = pack.faces
	for id in DOORS:
		var xmin := INF
		var xmax := -INF
		var ymin := INF
		var ymax := -INF
		var zmin := INF
		var zmax := -INF
		var count := 0
		for i in faces.size():
			var face: Dictionary = faces[i]
			if not owns(face) or int(face.source_index) != id: continue
			count += 1
			for point in face.points:
				var at: Array = point
				xmin = minf(xmin, float(at[0]))
				xmax = maxf(xmax, float(at[0]))
				ymin = minf(ymin, float(at[1]))
				ymax = maxf(ymax, float(at[1]))
				zmin = minf(zmin, float(at[2]))
				zmax = maxf(zmax, float(at[2]))
		if count == 0: continue
		var hinge := Vector3(xmin, 0.0, zmin)
		var pivot := Node3D.new()
		pivot.name = "MausDoor%d" % id
		pivot.position = hinge
		add_child(pivot)
		var body := AnimatableBody3D.new()
		body.name = "MoverCollision"
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = false
		pivot.add_child(body)
		var groups: Dictionary = {}
		for i in faces.size():
			var face: Dictionary = faces[i]
			if not owns(face) or int(face.source_index) != id: continue
			var material_key := str(face.material)
			if not groups.has(material_key):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[material_key] = surface
			var surface: SurfaceTool = groups[material_key]
			for corner in [0, 1, 2, 0, 2, 3]:
				var uv: Array = face.uv[corner]
				surface.set_uv(Vector2(float(uv[0]), float(uv[1])))
				var at: Array = face.points[corner]
				surface.add_vertex(Vector3(float(at[0]), float(at[1]), float(at[2])) - hinge)
		for key in groups:
			var surface: SurfaceTool = groups[key]
			var mesh := MeshInstance3D.new()
			mesh.mesh = surface.commit()
			var shape := CollisionShape3D.new()
			shape.shape = mesh.mesh.create_trimesh_shape()
			body.add_child(shape)
			var material := StandardMaterial3D.new()
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir() + "/" + str(pack.materials[key])))
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			var cutouts: Array = pack.get("alpha_cutout_materials", [])
			if key in cutouts: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mesh.material_override = material
			pivot.add_child(mesh)
		var leaf := Leaf.new()
		leaf.pivot = pivot
		leaf.body = body
		leaf.xmin = xmin
		leaf.xmax = xmax
		leaf.ymin = ymin
		leaf.ymax = ymax
		leaf.zmin = zmin
		leaf.zmax = zmax
		leaf.amount = 0.0
		leaf.opening = false
		leaves.append(leaf)
		body.force_update_transform()

func _physics_process(delta: float) -> void:
	if host == null or not is_instance_valid(host.player): return
	var where: Vector3 = host.player.position
	for leaf in leaves:
		if not leaf.opening and _near(leaf, where): leaf.opening = true
		if not leaf.opening or leaf.amount >= 1.0: continue
		leaf.amount = minf(1.0, leaf.amount + delta / OPEN_SECONDS)
		leaf.pivot.basis = Basis(Vector3.UP, OPEN_YAW * leaf.amount)
		leaf.body.force_update_transform()
		PhysicsServer3D.body_set_state(leaf.body.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, leaf.body.global_transform)

func _near(leaf: Leaf, where: Vector3) -> bool:
	var x: float = clampf(where.x, leaf.xmin, leaf.xmax)
	var y: float = clampf(where.y, leaf.ymin, leaf.ymax)
	var z: float = clampf(where.z, leaf.zmin, leaf.zmax)
	return Vector3(where.x - x, where.y - y, where.z - z).length() <= REACH
