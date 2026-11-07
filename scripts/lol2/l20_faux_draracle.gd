extends Node3D
## STORY-091 (HINTBOOK 5535-5546). Actor 46 is the only DRARACLE placement.
## No kill flag is stored. Crystal Keys 0, 1, and 2 opcode 1 door pairs.
## Opcode 1 was not entered, so the doors stay at current travel.
## Actor 75 is the BELIAL placement in region 177. No speech cstring was copied.
const KEY := "l20_faux_draracle"
const DRARACLE := 46
const BELIAL := 75
const GATEWAY := 52
const KEYS := [0, 1, 2]
const SPEECH := ""
const AT_46 := Vector3(-6921, -50, -4828)
const AT_0 := Vector3(-4636, -30, -4913)
const AT_1 := Vector3(-3485, -50, -4749)
const AT_2 := Vector3(-1043, 0, -3120)
const AT_75 := Vector3(-1238, -10, -3207)
const REACH := 20.0
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "struck": false, "killed": false, "keys": [], "room": false, "belial_seen": false}

static func moves_doors() -> bool:
	return false

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 6: return "Invalid draracle state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid draracle state."
	if not (s.get("struck") is bool) or not (s.get("killed") is bool) or not (s.get("room") is bool) or not (s.get("belial_seen") is bool): return "Invalid draracle state."
	if s.get("killed") != false: return "Invalid draracle state."
	var listed: Variant = s.get("keys")
	if not listed is Array: return "Invalid draracle state."
	var expect: int = 0
	for id in listed:
		if not (id is int or id is float) or int(id) != expect or expect > 2: return "Invalid draracle state."
		expect += 1
	var room: bool = bool(s.get("room"))
	if room != (expect == 3): return "Invalid draracle state."
	if bool(s.get("belial_seen")) and not room: return "Invalid draracle state."
	if bool(s.get("room")) and not bool(s.get("struck")): return "Invalid draracle state."
	return ""

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l20_faux_draracle.gd").new()
	n.host = map
	n.name = "L20FauxDraracle"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	var keys: Array = []
	var listed: Variant = raw.get("keys", [])
	if listed is Array:
		for id in listed:
			keys.append(int(id))
	var room: bool = keys.size() == 3
	return {"version": int(raw.get("version", 1)), "struck": bool(raw.get("struck", false)), "killed": false, "keys": keys, "room": room and bool(raw.get("struck", false)), "belial_seen": bool(raw.get("belial_seen", false)) and room}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func near_key() -> int:
	if flat_to(AT_0) < REACH: return 0
	if flat_to(AT_1) < REACH: return 1
	if flat_to(AT_2) < REACH: return 2
	return -1

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 564)
	canvas.add_child(hint)

func _process(_delta: float) -> void:
	hint.text = ""
	if host.flying or not host.starting_magic.world_active(): return
	if bool(state().room) and flat_to(AT_75) < REACH and not bool(state().belial_seen):
		var seen: Dictionary = state()
		seen.belial_seen = true
		seen.killed = false
		host.quest_state[KEY] = seen
	if flat_to(AT_46) < REACH:
		hint.text = "E — strike actor 46. The kill stays false."
	elif near_key() >= 0 and bool(state().struck):
		hint.text = "E — record the next key. The doors stay still."

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if flat_to(AT_46) < REACH:
		if int(host.player_form) != 0 or str(host.equipped_item) == "": return
		var hit: Dictionary = state()
		hit.struck = true
		hit.killed = false
		host.quest_state[KEY] = hit
		get_viewport().set_input_as_handled()
		return
	if not bool(state().struck): return
	var key: int = near_key()
	if key < 0: return
	var s: Dictionary = state()
	var keys: Array = s.keys
	if key != keys.size(): return
	keys.append(key)
	s.keys = keys
	s.room = keys.size() == 3
	s.killed = false
	host.quest_state[KEY] = s
	get_viewport().set_input_as_handled()
