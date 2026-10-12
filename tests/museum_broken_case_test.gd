extends SceneTree
## Headless control 181 Case. No museum scene and no rendered capture.
const Case = preload("res://scripts/lol2/museum_broken_case.gd")

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID], mask := 0xFFFFFFFF) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return space.intersect_ray(query)

func run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	current_scene = host
	var node: Node3D = Case.new()
	host.add_child(node)
	var catalog: Dictionary = node.catalog
	if node.face_count != 46 or node.meshes.size() != 6:
		fail("Case faces or materials changed")
		return
	var triangles := 0
	for mesh in node.meshes:
		triangles += mesh.mesh.surface_get_array_len(0) / 3
	if triangles != 92:
		fail("Case triangle count changed")
		return
	for face in catalog.faces:
		if int(face.child) < 26 or int(face.child) > 34:
			fail("Sword or empty child staged")
			return
	var box: BoxShape3D = node.contact.get_child(0).shape
	var at: Vector3 = node.contact.get_child(0).position
	if box.size != Vector3(22, 70, 22) or at != Vector3(981, 50, -2552):
		fail("Contact volume changed")
		return
	if node.contact.collision_layer != 1 or node.contact.collision_mask != 0:
		fail("Contact layer changed")
		return
	if node.visibility.collision_layer != 1 << 19 or node.visibility.collision_mask != 0:
		fail("Visibility layer changed")
		return
	var sword: Vector3 = node.sword_anchor()
	if sword != Vector3(981, 53, -2552):
		fail("Native sword anchor changed")
		return
	# Sword quad 16x25 from the anchor sits inside the inner posts, above plinth49, under ring81.
	if sword.x - 8 < 973 or sword.x + 8 > 989 or sword.y < 49 or sword.y + 25 > 81:
		fail("Sword does not fit the case opening")
		return
	await physics_frame
	await physics_frame
	var space := node.get_world_3d().direct_space_state
	var aim := sword + Vector3(0, 12.5, 0)
	var eye := Vector3(981, 66, -2552 + 60)
	var none: Array[RID] = []
	var hit := ray(space, eye, aim, none)
	if hit.is_empty() or hit.collider != node.contact:
		fail("Contact volume does not enclose the sword")
		return
	var excluded: Array[RID] = node.interaction_exclude()
	if not ray(space, eye, aim, excluded).is_empty():
		fail("Open side blocks the item ray")
		return
	for side in [Vector3(60, 0, 0), Vector3(-60, 0, 0), Vector3(0, 0, -60)]:
		if not ray(space, aim + side + Vector3(0, 0.5, 0), aim, excluded).is_empty():
			fail("Open side blocks the item ray: %s" % side)
			return
	hit = ray(space, Vector3(990, 65, -2500), Vector3(990, 65, -2552), excluded)
	if hit.is_empty() or hit.collider != node.visibility:
		fail("Post does not occlude the ray")
		return
	hit = ray(space, Vector3(981, 20, -2500), Vector3(981, 20, -2552), excluded)
	if hit.is_empty() or hit.collider != node.visibility:
		fail("Pedestal does not occlude the ray")
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = 8
	capsule.height = 64
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = capsule
	shape.collision_mask = 1
	shape.transform = Transform3D(Basis(), Vector3(981, 47, -2552 + 18))
	var hits := space.intersect_shape(shape)
	if hits.size() != 1 or hits[0].collider != node.contact:
		fail("Player mask must meet contact only")
		return
	shape.transform = Transform3D(Basis(), Vector3(981, 47, -2552 + 19.5))
	if not space.intersect_shape(shape).is_empty():
		fail("Capsule clear of the 11-unit half depth is blocked")
		return
	print("PASS museum broken case faces=46 triangles=92 contact=22x70x22 sword=", sword)
	quit(0)
