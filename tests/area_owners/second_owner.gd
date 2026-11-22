extends Node
const KEY := "f16_second"
const RESTORE_ON := ["load"]
var host: Node
static func attach_entry(map: Node, tag: String) -> Node:
	var node = load("res://tests/area_owners/second_owner.gd").new()
	node.host = map
	node.name = tag
	map.add_child(node)
	return node
static func owns(face: Dictionary) -> bool: return face.get("source_index") == 779
func restore(saved: bool) -> String:
	host.calls.append(str(name) + ":" + str(saved))
	return "Second refused." if host.fail else ""
static func validate(value: Variant) -> String: return "" if value is bool else "Invalid second."
