extends Node3D
## L8 tree bridge. E at control 114 unlinks assembly 114 and links assembly 116.
## Opcode 9 arm 3 is the host link. Opcode 9 arm 2 is the host player release, not a mesh unlink.
## The port rule still unlinks 114 and links 116. Assembly 116 starts absent (flag 0x1000).
## OP9_ENTERED stays false: the calls after the link stores were not entered.
## Opcode 20 is sound 780 creaky2.aud. No movie is stored. Playback stays off. No fall distance is stored.
const KEY: String = "l8_tree_bridge"
const TREE := 114
const BRIDGE := 116
const AT := Vector3(5096, 0, 1916)
const REACH := 64.0
const OP9_ENTERED := false
const OP9_ARM2 := "player_release"
const OP9_ARM3 := "link"
const SOUND_ID := 780
const SOUND_NAME := "creaky2.aud"
const OP20_PLAYED := false
var host: Node3D

static func initial() -> Dictionary:
	return {"version": 1, "knocked": false}

static func validate(saved: Variant, quests: Dictionary) -> String:
	if not quests is Dictionary: return "Invalid tree bridge."
	if not saved is Dictionary or saved.size() != 2 or int(saved.get("version", 0)) != 1 or not saved.get("knocked") is bool:
		return "Invalid tree bridge."
	return ""

static func owns(face: Dictionary) -> bool:
	if face.get("kind") != "movable" or face.get("placement_kind") != "static_assembly": return false
	var id := int(face.get("source_index", -1))
	return id == TREE or id == BRIDGE

static func attach(map: Node3D) -> Node:
	var node: Node = load("res://scripts/lol2/l8_tree_bridge.gd").new()
	node.host = map
	node.name = "L8TreeBridge"
	map.add_child(node)
	return node

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

func flat_distance() -> float:
	var delta: Vector3 = host.player.global_position - AT
	return Vector2(delta.x, delta.z).length()

func restore() -> void:
	var assemblies: Variant = host.get("preview_assemblies")
	if assemblies == null or not is_instance_valid(assemblies): return
	var knocked: bool = bool(state().knocked)
	assemblies.set_present(TREE, not knocked)
	assemblies.set_present(BRIDGE, knocked)

func use() -> bool:
	if host.get_tree().paused or bool(host.flying): return false
	if flat_distance() > REACH: return false
	if not bool(state().knocked):
		host.quest_state[KEY] = {"version": 1, "knocked": true}
		restore()
		if host.has_method("save_feedback"): host.save_feedback("The tree lies across the chasm.")
	return true

func _ready() -> void:
	restore()

func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if use(): get_viewport().set_input_as_handled()
