extends Node3D
## L1_DC movables 74 and 77, the double leaf across the arch in front of the Draracle
## (owner r17 16-25-58). Templates 11 and 10, resource 478, word 0x0582, drawn and solid.
## Kind-4 use: owner state 0 runs opcode 1 at percent 100 on both leaves (travel 21845).
## State 1 returns travel to 0. A later use of that same leaf matches neither predicate.
## Byte 34 is 6, so opcode 1 is the proven rotary write. The hinge corner is the mode
## table (74 mode 7, 77 mode 4). The pose snaps; the swing clock at +0x55 is not modelled.
## Opcode 16 and opcode 197 on region 1906 stay unread. Saved as "cave_draracle_door".
## OF1. Template 11 (leaf 74) stores surface byte +6 = 0x40 on box face 2 and 0 on face 3.
## The bake mirrored face 3 only. The source UVs for those two faces follow the flag.
const SOURCE := "res://scripts/lol2/cave_draracle_door_source.json"
const Assemblies = preload("res://scripts/lol2/static_assemblies.gd")
const LEAVES: Array[String] = ["74", "77"]

var host: Node3D
var src: Dictionary = {}
var uses: Dictionary = {}
var travel := 0
var meshes: Dictionary = {}
var shapes: Dictionary = {}
var closed_mesh: Dictionary = {}
var open_mesh: Dictionary = {}
var closed_hull: Dictionary = {}
var open_hull: Dictionary = {}
var closed_box: Dictionary = {}
var open_box: Dictionary = {}

static func source() -> Dictionary:
	if not FileAccess.file_exists(SOURCE):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	return parsed if parsed is Dictionary else {}

static func assets_ready() -> bool:
	var data := source()
	if data.is_empty() or not data.has("material"):
		return false
	var path := str(data.material)
	if not FileAccess.file_exists(path):
		return false
	return FileAccess.get_sha256(path) == str(data.get("material_sha256", ""))

static func initial() -> Dictionary:
	return {"version": 1, "uses": {"74": 0, "77": 0}, "travel": 0}

static func validate(saved: Variant, source_data: Dictionary) -> String:
	if not saved is Dictionary:
		return "Invalid Draracle door state."
	var row: Dictionary = saved
	if row.size() != 3 or not row.has_all(["version", "uses", "travel"]):
		return "Invalid Draracle door state."
	if not (row.version is int or row.version is float) or int(row.version) != 1:
		return "Invalid Draracle door state."
	if not (row.travel is int or row.travel is float):
		return "Invalid Draracle door state."
	var travel_n := int(row.travel)
	var full := int(source_data.get("full_travel", -1))
	if travel_n != 0 and travel_n != full:
		return "Invalid Draracle door state."
	if not row.uses is Dictionary:
		return "Invalid Draracle door state."
	var raw: Dictionary = row.uses
	if raw.size() != 2:
		return "Invalid Draracle door state."
	var total := 0
	for id in LEAVES:
		if not raw.has(id):
			return "Invalid Draracle door state."
		var count: Variant = raw[id]
		if not (count is int or count is float) or not is_finite(float(count)) or float(count) != floorf(float(count)) or float(count) < 0.0:
			return "Invalid Draracle door state."
		total += int(count)
	if total == 0 and travel_n != 0:
		return "Invalid Draracle door state."
	return ""

func setup(owner_host: Node3D) -> String:
	host = owner_host
	name = "CaveDraracleDoor"
	src = source()
	if src.is_empty():
		return "Draracle door source missing."
	if not assets_ready():
		return "Draracle door material missing."
	var offset_v: Variant = host.get("native_translation")
	if not offset_v is Vector3:
		return "Draracle door needs the cave translation."
	var offset: Vector3 = offset_v
	var material_v: Variant = host.call("_indexed_material", str(src.material))
	if not material_v is ShaderMaterial:
		return "Draracle door material missing."
	var material: ShaderMaterial = material_v
	var leaves: Dictionary = src.leaves
	for id in LEAVES:
		if not leaves.has(id) or not leaves[id] is Dictionary:
			return "Draracle door leaf %s missing." % id
		var leaf: Dictionary = leaves[id]
		var shut: Dictionary = leaf.closed
		var swung: Dictionary = leaf.open
		closed_mesh[id] = _mesh_from(shut, offset)
		open_mesh[id] = _mesh_from(swung, offset)
		closed_hull[id] = _hull_from(shut, offset)
		open_hull[id] = _hull_from(swung, offset)
		closed_box[id] = _box_from(closed_hull[id] as ConvexPolygonShape3D)
		open_box[id] = _box_from(open_hull[id] as ConvexPolygonShape3D)
		var mesh := MeshInstance3D.new()
		mesh.name = "Leaf" + id
		mesh.mesh = closed_mesh[id]
		mesh.material_override = material
		mesh.layers = 2
		add_child(mesh)
		meshes[id] = mesh
		if host.has_method("_copy_occluders"):
			host.call("_copy_occluders", mesh)
		var body := StaticBody3D.new()
		body.name = "Solid" + id
		body.collision_layer = Assemblies.SCENERY_LAYER
		body.collision_mask = 0
		body.add_to_group("draracle_leaf")
		body.set_meta("draracle_leaf", id)
		var shape := CollisionShape3D.new()
		shape.shape = closed_hull[id]
		body.add_child(shape)
		add_child(body)
		shapes[id] = shape
	var player_v: Variant = host.get("player")
	if player_v is CollisionObject3D:
		(player_v as CollisionObject3D).collision_mask |= Assemblies.SCENERY_LAYER
	return restore(null)

func checkpoint() -> Dictionary:
	return {"version": 1, "uses": {"74": int(uses.get("74", 0)), "77": int(uses.get("77", 0))}, "travel": travel}

func restore(saved: Variant) -> String:
	var proposed: Variant = initial() if saved == null else saved
	var error := validate(proposed, src)
	if not error.is_empty():
		return error
	var row: Dictionary = proposed
	var raw: Dictionary = row.uses
	uses = {"74": int(raw["74"]), "77": int(raw["77"])}
	travel = int(row.travel)
	_apply_pose()
	return ""

## The leaf the camera is looking at, within reach. The aim point is the spot on
## that leaf's box nearest the camera, so a tall leaf still counts when the eye is low.
func aimed() -> String:
	if not is_instance_valid(host):
		return ""
	var cam_v: Variant = host.get("camera")
	if not cam_v is Camera3D:
		return ""
	var cam: Camera3D = cam_v
	var reach := float(src.get("reach", 120.0))
	var facing := float(src.get("facing", 0.7))
	var forward := -cam.global_basis.z
	var best := ""
	var best_dot := facing
	for id in LEAVES:
		var point := _aim_point(id, cam.global_position)
		var offset := point - cam.global_position
		var dist := offset.length()
		if dist > reach:
			continue
		var dot := 1.0 if dist <= 0.001 else forward.dot(offset / dist)
		if dot > best_dot:
			best_dot = dot
			best = id
	return best

func prompt() -> String:
	var id := aimed()
	if id.is_empty():
		return ""
	var count := int(uses.get(id, 0))
	if count == 0:
		return "E · Open the door"
	if count == 1:
		return "E · Close the door"
	return ""

## Kind-4 use of the aimed leaf. State 0 opens both. State 1 closes both.
func try_use() -> bool:
	var id := aimed()
	if id.is_empty():
		return false
	var count := int(uses.get(id, 0))
	if count >= 2:
		return true
	uses[id] = count + 1
	travel = 0 if count == 1 else int(src.full_travel)
	_apply_pose()
	return true

func _apply_pose() -> void:
	for id in LEAVES:
		if not meshes.has(id):
			continue
		var mesh: MeshInstance3D = meshes[id]
		mesh.mesh = _mesh_for(id)
		var shape_node: CollisionShape3D = shapes[id]
		shape_node.shape = _hull_for(id)
		_retarget(mesh)

func _retarget(source: MeshInstance3D) -> void:
	if not is_instance_valid(host):
		return
	var occluders: Variant = host.get("occluder_by_source")
	if occluders is Dictionary and (occluders as Dictionary).has(source):
		var dup: Variant = (occluders as Dictionary)[source]
		if dup is MeshInstance3D:
			(dup as MeshInstance3D).mesh = source.mesh
	var lights: Variant = host.get("light_by_source")
	if lights is Dictionary and (lights as Dictionary).has(source):
		var lit: Variant = (lights as Dictionary)[source]
		if lit is MeshInstance3D:
			(lit as MeshInstance3D).mesh = source.mesh

func _mesh_for(id: String) -> ArrayMesh:
	var book: Dictionary = open_mesh if travel != 0 else closed_mesh
	return book[id] as ArrayMesh

func _hull_for(id: String) -> ConvexPolygonShape3D:
	var book: Dictionary = open_hull if travel != 0 else closed_hull
	return book[id] as ConvexPolygonShape3D

func _aim_point(id: String, cam: Vector3) -> Vector3:
	var book: Dictionary = open_box if travel != 0 else closed_box
	var raw: Variant = book[id]
	if not raw is AABB:
		return cam
	var box: AABB = raw
	return Vector3(
		clampf(cam.x, box.position.x, box.end.x),
		clampf(cam.y, box.position.y, box.end.y),
		clampf(cam.z, box.position.z, box.end.z))

func _mesh_from(pose: Dictionary, offset: Vector3) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: Array = pose.faces
	var order: Array[int] = [0, 1, 2, 0, 2, 3]
	for face_v in faces:
		var face: Dictionary = face_v
		var uv: Array = face.uv
		var pts: Array = face.points
		for i in order:
			var uv_row: Array = uv[i]
			var p: Array = pts[i]
			surface.set_uv(Vector2(float(uv_row[0]), float(uv_row[1])))
			surface.add_vertex(Vector3(float(p[0]), float(p[1]), float(p[2])) + offset)
	surface.generate_normals()
	return surface.commit()

func _hull_from(pose: Dictionary, offset: Vector3) -> ConvexPolygonShape3D:
	var shape := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	var hull: Array = pose.hull
	for row in hull:
		var p: Array = row
		pts.append(Vector3(float(p[0]), float(p[1]), float(p[2])) + offset)
	shape.points = pts
	return shape

func _box_from(shape: ConvexPolygonShape3D) -> AABB:
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for p in shape.points:
		low = low.min(p)
		high = high.max(p)
	return AABB(low, high - low)
