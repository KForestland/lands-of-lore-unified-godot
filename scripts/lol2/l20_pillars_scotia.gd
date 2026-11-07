extends Node3D
## STORY-088 and STORY-089 (HINTBOOK 5492-5511). Fire pillars 57-61 are one row.
## No blue cstring is stored. A shot does not open a path. Actor 48 is the near
## SCOTIA placement. Actor 65 is the other one. Actor 47 is DRAR_PH. No prism
## opcode 3 is stored. The level is the constant 5. Pillars do not move.
## Regions 1475-1479 and 1484-1488 are the only level-change owners. Byte 0x53
## splits as level 19 selector 2. This module does not take that exit.
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
const KEY := "l20_pillars"
const FIRE := [57, 58, 59, 60, 61]
const ICE := 62
const BLUE := -1
const SCOTIA := 48
const OTHER_SCOTIA := 65
const DRAR_PH := 47
const PRISM := -1
const TRINITY_LEVEL := 5
const DEST_BYTE := 0x53
const DEST_LEVEL := 19
const DEST_SELECTOR := 2
const STAIR_REGIONS := [1475, 1476, 1477, 1478, 1479, 1484, 1485, 1486, 1487, 1488]
const AT_57 := Vector3(-3340, -50, -4299)
const AT_58 := Vector3(-3404, -50, -4299)
const AT_59 := Vector3(-3482, -50, -4299)
const AT_60 := Vector3(-3559, -50, -4299)
const AT_61 := Vector3(-3636, -50, -4299)
const AT_62 := Vector3(-3400, -50, -4463)
const SCOTIA_AT := Vector3(-3539, -50, -3877)
const OTHER_AT := Vector3(-2207, -50, -1180)
const DRAR_AT := Vector3(-3576, -50, -3986)
const STAIR_AT := Vector3(-2612, 0, -4262)
const REACH := 20.0
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "shot": [], "trinity": false, "path_open": false, "pillars_moved": false}

static func opens_path() -> bool:
	return false

static func moves_pillars() -> bool:
	return false

static func relocates_player() -> bool:
	return false

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 5: return "Invalid pillar state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid pillar state."
	if not (s.get("trinity") is bool) or not (s.get("path_open") is bool) or not (s.get("pillars_moved") is bool): return "Invalid pillar state."
	if s.get("path_open") != false or s.get("pillars_moved") != false: return "Invalid pillar state."
	var listed: Variant = s.get("shot")
	if not listed is Array: return "Invalid pillar state."
	var seen: Dictionary = {}
	for id in listed:
		if not (id is int or id is float) or seen.has(int(id)) or not (int(id) in FIRE): return "Invalid pillar state."
		seen[int(id)] = true
	return ""

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l20_pillars_scotia.gd").new()
	n.host = map
	n.name = "L20PillarsScotia"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	var shot: Array = []
	var listed: Variant = raw.get("shot", [])
	if listed is Array:
		for id in listed:
			shot.append(int(id))
	return {"version": int(raw.get("version", 1)), "shot": shot, "trinity": bool(raw.get("trinity", false)), "path_open": false, "pillars_moved": false}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func near_fire() -> int:
	if flat_to(AT_57) < REACH: return 57
	if flat_to(AT_58) < REACH: return 58
	if flat_to(AT_59) < REACH: return 59
	if flat_to(AT_60) < REACH: return 60
	if flat_to(AT_61) < REACH: return 61
	return -1

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 532)
	canvas.add_child(hint)

func _process(_delta: float) -> void:
	hint.text = ""
	if host.flying or not host.starting_magic.world_active(): return
	if near_fire() >= 0:
		hint.text = "E — shoot. Blue stays -1. The path stays closed."
	elif flat_to(SCOTIA_AT) < REACH:
		hint.text = "E — level-five Trinity. Actor 48 is not a kill."

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if flat_to(SCOTIA_AT) < REACH:
		if not Forms.can_cast(int(host.player_form)): return
		var cast: Dictionary = state()
		cast.trinity = true
		cast.path_open = false
		cast.pillars_moved = false
		host.quest_state[KEY] = cast
		get_viewport().set_input_as_handled()
		return
	if flat_to(OTHER_AT) < REACH or flat_to(DRAR_AT) < REACH: return
	if int(host.player_form) != 0 or str(host.equipped_item) == "": return
	var id: int = near_fire()
	if id < 0: return
	var s: Dictionary = state()
	var shot: Array = s.shot
	if id in shot: return
	shot.append(id)
	s.shot = shot
	s.path_open = false
	s.pillars_moved = false
	host.quest_state[KEY] = s
	get_viewport().set_input_as_handled()
