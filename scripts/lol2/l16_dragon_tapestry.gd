extends Node3D
## Dragon-room tapestry. Static assembly 92 is one quad at z 5181
## (material 425, y 30 to 130, flags 0x482, depth 0). Control 92 sits
## on the same placement. Kind 4 does not clear the solid bit. Kind 6
## value 2 does, through opcode 9 arm 8, and the control-event caller
## is not known. g_00319 shows the mural at the end of an open hall.
## g_00321 is inside beside it. The drawn face stays. Collision on this
## face is omitted. Movable 92, the north-east FireWall, is a different
## placement and is left alone.
static var omitted: int = 0

static func owns(face: Dictionary) -> bool:
	if str(face.get("placement_kind", "")) != "static_assembly":
		return false
	var source: Variant = face.get("source_index", -1)
	if not (source is int or source is float) or int(source) != 92:
		return false
	omitted += 1
	return true

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l16_dragon_tapestry.gd").new()
	n.name = "L16DragonTapestry"
	map.add_child(n)
	return n

static func relocates_player() -> bool:
	return false

func _ready() -> void:
	print("TAPESTRY 92 collision omitted, faces ", omitted)
