extends Node3D
## L1_DC movable 55: the rock slab with the crack-shaped hole in the scenic-guard doorway (tools/prepare_cave_crack_movable.py,
## owner R19 report 10:51:27). The level wall leaves a 40 x 75 rectangular doorway; the original fills it with this slab,
## whose resource 284 texture has the irregular crack opening (index 0). No records: plain scenery. Drawn like the
## static assemblies (indexed cutout, layer 2, occluder copies) plus its native solid box (word8 0x80, template 50 box)
## on the scenery layer, so the player looks through the crack but cannot walk through the doorway.
const ROOT := "res://assets/lol2/generated/cave_crack_movable/"
var data: Dictionary = {}
var mesh: MeshInstance3D
var body: StaticBody3D

static func assets_ready() -> bool:
	return FileAccess.file_exists(ROOT + "movable.json") and FileAccess.file_exists(ROOT + "material_0284.png")

func setup(host: Node3D) -> String:
	name = "CaveCrackMovable55"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "movable.json"))
	if not parsed is Dictionary or int(parsed.get("movable", -1)) != 55: return "Cave crack movable pack invalid."
	data = parsed
	if FileAccess.get_sha256(ROOT + str(data.material.image)) != str(data.material.sha256): return "Cave crack material changed."
	var offset: Vector3 = host.native_translation
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in data.faces:
		for i in [0, 1, 2, 0, 2, 3]:
			surface.set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
			surface.add_vertex(Vector3(face.points[i][0], face.points[i][1], face.points[i][2]) + offset)
	mesh = MeshInstance3D.new()
	mesh.name = "Slab"
	mesh.mesh = surface.commit()
	var material: ShaderMaterial = host._indexed_material(ROOT + str(data.material.image))
	if material == null: return "Cave crack material missing."
	material.set_shader_parameter("cutout", true)
	mesh.material_override = material
	mesh.layers = 2
	add_child(mesh)
	if host.has_method("_copy_occluders"): host._copy_occluders(mesh)
	var b: Dictionary = data.box
	var p: Dictionary = data.placement
	body = StaticBody3D.new()
	body.name = "Solid55"
	body.collision_layer = preload("res://scripts/lol2/static_assemblies.gd").SCENERY_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(b.width), float(b.height), float(b.depth))
	shape.shape = box
	body.add_child(shape)
	# Native y -> Godot -z; heading H turns the width axis to map angle H (Godot Y rotation -H), as static_assemblies.gd.
	body.position = Vector3(float(p.x), float(p.h) + float(b.height) / 2.0, -float(p.y)) + offset
	body.rotation.y = -float(p.heading) / 65536.0 * TAU
	add_child(body)
	if host.get("player") is CollisionObject3D: host.player.collision_mask |= body.collision_layer
	return ""
