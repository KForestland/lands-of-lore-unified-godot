extends Node
const KEY := "f16_dummy"
const RESTORE_ON := ["load", "arrival"]
var host: Node
static func attach(map: Node, tag: String = "Dummy") -> Node:
	var node = load("res://tests/area_owners/dummy_owner.gd").new()
	node.host = map
	node.name = tag
	map.add_child(node)
	return node
static func owns(face: Dictionary) -> bool: return face.get("source_index") == 777
static func owns_collision(face: Dictionary) -> bool: return face.get("source_index") == 778
func restore() -> void: host.calls.append(name)
static func validate(value: Variant, quests: Dictionary) -> String:
	return "" if value is Dictionary and value == {"ok": true} and quests.has(KEY) else "Invalid dummy."
