extends Node3D
## L8 cache ladder. Control 69, region 678, floor -10. Opcode 18 words (-1004, 2590, height 100)
## land in region 657. Target u16 0 stays unnamed, so the player moves.
## Opcode 20 is sound 780 creaky2.aud. No movie is stored. Playback stays off.
const KEY: String = "l8_cache_ladder"
const CONTROL: int = 69
const AT := Vector3(-1034, -10, -2606)
const DEST := Vector3(-1004, 100, -2590)
const REACH := 64.0
const SOUND_ID := 780
const SOUND_NAME := "creaky2.aud"
const OP20_PLAYED := false
var host: Node3D

static func initial() -> Dictionary:
	return {"version": 1, "climbed": false}

static func validate(saved: Variant, quests: Dictionary) -> String:
	if not quests is Dictionary: return "Invalid cache ladder."
	if not saved is Dictionary or saved.size() != 2 or int(saved.get("version", 0)) != 1 or not saved.get("climbed") is bool:
		return "Invalid cache ladder."
	return ""

static func attach(map: Node3D) -> Node:
	var node: Node = load("res://scripts/lol2/l8_cache_ladder.gd").new()
	node.host = map
	node.name = "L8CacheLadder"
	map.add_child(node)
	return node

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

func flat_distance() -> float:
	var delta: Vector3 = host.player.global_position - AT
	return Vector2(delta.x, delta.z).length()

func use() -> bool:
	if host.get_tree().paused or bool(host.flying): return false
	if flat_distance() > REACH: return false
	if not bool(state().climbed):
		var feet: float = preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
		host.player.position = DEST + Vector3(0, feet, 0)
		host.quest_state[KEY] = {"version": 1, "climbed": true}
		if host.has_method("save_feedback"): host.save_feedback("You climb the ladder.")
	return true

func restore() -> void:
	pass

func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if use(): get_viewport().set_input_as_handled()
