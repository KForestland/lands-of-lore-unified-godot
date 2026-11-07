extends Node3D
## STORY-090 (HINTBOOK 5522-5534). Controls 62-67 are Block. Control 62 is the
## westernmost. Record height is -110. Nav floor of region 126 is -30.
## No brick, white ball, or fireball cstring is stored. Props 195, 196, and 197
## stay unbound. Opcode 20 was not entered. Pillars do not stop.
const KEY := "l20_armory"
const LEFTMOST := 62
const OTHER := 67
const BRICK := -1
const BALL := -1
const FIREBALL := -1
const SOURCES := [195, 196, 197]
const PYRAPOD := -1
const IMP_LEVEL := 3
const BLUE_BOW := "act2:L12_CM:blue_bow"
const AT_62 := Vector3(-1375, -30, -1719)
const AT_67 := Vector3(-547, -23, -1726)
const AT_195 := Vector3(-3880, -50, -2630)
const AT_196 := Vector3(-2650, -50, -2924)
const AT_197 := Vector3(-3619, -50, -3431)
const REACH := 20.0
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "hacked": false, "ball": false, "fire": false, "stopped": false}

static func stops_pillars() -> bool:
	return false

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 5: return "Invalid armory state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid armory state."
	if not (s.get("hacked") is bool) or not (s.get("ball") is bool) or not (s.get("fire") is bool) or not (s.get("stopped") is bool): return "Invalid armory state."
	if s.get("ball") != false or s.get("fire") != false or s.get("stopped") != false: return "Invalid armory state."
	return ""

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l20_armory.gd").new()
	n.host = map
	n.name = "L20Armory"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	return {"version": int(raw.get("version", 1)), "hacked": bool(raw.get("hacked", false)), "ball": false, "fire": false, "stopped": false}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 548)
	canvas.add_child(hint)

func _process(_delta: float) -> void:
	hint.text = ""
	if host.flying or not host.starting_magic.world_active(): return
	if flat_to(AT_62) < REACH:
		hint.text = "E — hack the westernmost block. The brick id stays -1."

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if flat_to(AT_62) >= REACH: return
	if int(host.player_form) != 0 or str(host.equipped_item) == "": return
	var s: Dictionary = state()
	s.hacked = true
	s.ball = false
	s.fire = false
	s.stopped = false
	host.quest_state[KEY] = s
	get_viewport().set_input_as_handled()
