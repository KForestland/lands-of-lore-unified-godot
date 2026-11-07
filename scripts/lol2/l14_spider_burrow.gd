extends Node3D
## L14 spider burrow receipt. Owner point Godot (3061, 0, -5374), native (3061, 5374).
## Controls 80 and 81: opcode 2 arm 0x11 sets the link bit, then calls 0xB3B04, 0xB3AC4, and 0xD8D48.
## Those three calls were not entered. Opcode 9 arm 6 is not decoded.
## Opcode 9 arm 2 on props 194-199 is the host player release.
## Opcode 20 is sound 452 jugcrash.aud. Playback stays off.
## No floor distance is stored. The floor quads stay where the pack built them.
## l14_spider_passage stays on the hanging wall. Caller byte 7 was not joined, so E is the adapter.
const KEY: String = "l14_spider_burrow"
const AT := Vector3(3061, 0, -5374)
const REACH := 64.0
const SOUND_ID := 452
const SOUND_NAME := "jugcrash.aud"
const OP20_PLAYED := false
const ARM6_DECODED := false
const FLOOR_MOVED := false
var host: Node3D

static func initial() -> Dictionary:
	return {"version": 1, "struck": false}

static func validate(saved: Variant, quests: Dictionary) -> String:
	if not quests is Dictionary: return "Invalid spider burrow."
	if not saved is Dictionary or saved.size() != 2 or int(saved.get("version", 0)) != 1 or not saved.get("struck") is bool:
		return "Invalid spider burrow."
	return ""

static func attach(map: Node3D) -> Node:
	var node: Node = load("res://scripts/lol2/l14_spider_burrow.gd").new()
	node.host = map
	node.name = "L14SpiderBurrow"
	map.add_child(node)
	return node

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

func flat_distance() -> float:
	var delta: Vector3 = host.player.global_position - AT
	return Vector2(delta.x, delta.z).length()

func use() -> bool:
	if host.get_tree() != null and host.get_tree().paused: return false
	if host.get("flying") == true: return false
	if flat_distance() > REACH: return false
	if not bool(state().struck):
		host.quest_state[KEY] = {"version": 1, "struck": true}
		if host.has_method("save_feedback"): host.save_feedback("The ceiling groans.")
	return true

func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if use(): get_viewport().set_input_as_handled()
