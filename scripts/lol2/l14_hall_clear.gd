extends Node3D
## L14 hall opening. Region 16 edge 2, native (2900, 3254)-(2743, 3266), heights 0-80.
## Longplay g_276 and g_278 clear that opening to black. No collision.
const A := Vector3(2900, 0, -3254)
const B := Vector3(2743, 0, -3266)
const TOP := 80.0
const OWNER_VIEW := Vector3(2926, 42, -3268)   # owner report 2026-11-12 06-25-52

static func attach(map: Node3D) -> Node:
	var node: Node = load("res://scripts/lol2/l14_hall_clear.gd").new()
	node.name = "L14HallClear"
	map.add_child(node)
	return node

func _ready() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_a := Vector3(A.x, TOP, A.z)
	var top_b := Vector3(B.x, TOP, B.z)
	# One-sided (lead decision 2026-11-12, owner report 06-25-52): black only seen from the side opposite the owner's
	# view of 06-25-52 (camera 2926,-3268, on the positive side of A->B); from his side the room behind shows.
	var line := Vector2(B.x - A.x, B.z - A.z)
	var away := Vector2(-line.y, line.x).normalized() * (-1.0 if line.cross(Vector2(OWNER_VIEW.x - A.x, OWNER_VIEW.z - A.z)) > 0.0 else 1.0)
	var toward := Vector3(away.x, 0, away.y)
	var order: Array = [A, B, top_b, A, top_b, top_a]
	# Godot front faces wind the other way round from the right-hand normal (same rule as jungle_review _winding).
	if (B - A).cross(top_b - A).dot(toward) > 0.0: order = [A, top_b, B, A, top_a, top_b]
	for point in order:
		tool.add_vertex(point)
	var mesh := MeshInstance3D.new()
	mesh.name = "Clear"
	mesh.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0, 0, 0, 1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	mesh.material_override = material
	add_child(mesh)
