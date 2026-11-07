extends Node3D
## L14 hall opening. Region 16 edge 2, native (2900, 3254)-(2743, 3266), heights 0-80.
## Longplay g_276 and g_278 clear that opening to black. No collision.
const A := Vector3(2900, 0, -3254)
const B := Vector3(2743, 0, -3266)
const TOP := 80.0

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
	for point in [A, B, top_b, A, top_b, top_a]:
		tool.add_vertex(point)
	var mesh := MeshInstance3D.new()
	mesh.name = "Clear"
	mesh.mesh = tool.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0, 0, 0, 1)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	add_child(mesh)
