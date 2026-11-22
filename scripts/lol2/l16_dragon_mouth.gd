extends Node3D
## Dragon-room mouth. Movable 103 is static slot 59 Door, mode 6, flags 0x0582.
## Its only opcode 1 writes travel 0. Kind 6 value 16 is opcode 197 arm 7 on
## region 9622, which is not a movement-drop bit.
## g_00319 shows the winged mural at the end of an open hall. g_00321 is inside
## at that mural. No opened frame shows this slab swinging. The drawn faces stay.
## Collision on this one movable is removed. Region 9622 is left as it is.
const DOOR := 103

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l16_dragon_mouth.gd").new()
	n.name = "L16DragonMouth"
	map.add_child(n)
	n.drop(map)
	return n

static func relocates_player() -> bool:
	return false

func drop(map: Node3D) -> bool:
	var progression: Node = map.get("progression")
	if progression == null:
		return false
	var hinge: Node = progression.get_node_or_null("Movable%d" % DOOR)
	if hinge == null:
		return false
	var body: Node = hinge.get_node_or_null("MoverCollision")
	if body is CollisionObject3D:
		(body as CollisionObject3D).collision_layer = 0
		hinge.remove_child(body)
		body.free()
	var movers: Variant = progression.get("mover_bodies")
	if movers is Dictionary:
		(movers as Dictionary).erase(DOOR)
	var meshes := 0
	for child in hinge.get_children():
		if child is MeshInstance3D:
			meshes += 1
	print("MOUTH 103 collision dropped, meshes ", meshes)
	return meshes > 0
