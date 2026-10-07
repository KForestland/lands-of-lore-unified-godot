extends StaticBody3D
## Authored support at the recovered item position; original table mesh unresolved.
const ITEM_POSITION := preload("res://scripts/lol2/museum_sword_transfer.gd").TABLE_SWORD
const TOP := 47.5

func _ready() -> void:
	# Keep the original sword near the front edge so a source-height human
	# can see and reach it over this authored support.
	position = Vector3(ITEM_POSITION.x, 0, ITEM_POSITION.z - 89.0)
	# Four slightly separated planks make the top legible with the unlit scene.
	for index in range(4):
		add_box(Vector3(-31.5 + index * 21, 46, 0), Vector3(20.5, 3, 186),
			Color("66503b") if index % 2 == 0 else Color("705841"), false)
	add_collision(Vector3(0, 46, 0), Vector3(84, 3, 186))
	for x in [-33, 33]:
		for z in [-85, 85]:
			add_box(Vector3(x, 22.25, z), Vector3(6, 44.5, 6), Color("403124"), true)
	for z in [-88, 88]:
		add_box(Vector3(0, 40, z), Vector3(72, 8, 4), Color("4d3b2b"), true)
	for x in [-36, 36]:
		add_box(Vector3(x, 40, 0), Vector3(4, 8, 176), Color("4d3b2b"), true)

func add_box(center: Vector3, dimensions: Vector3, color: Color, solid: bool) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.material = material
	instance.mesh = mesh
	instance.position = center
	add_child(instance)
	if solid: add_collision(center, dimensions)

func add_collision(center: Vector3, dimensions: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	collider.shape = box
	collider.position = center
	add_child(collider)
