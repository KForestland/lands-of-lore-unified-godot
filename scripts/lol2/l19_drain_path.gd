extends Node3D
## STORY-083 and STORY-084 (HINTBOOK 5433-5456). Throwing the switches again can
## drain the guck. Leaving it is allowed. The short path clicks a door, then the
## book's turns and the rapids. Switches 50, 71, and 72 are the decoded second
## set. Clicking the door opens the Golden Doors 51 and 52 through their native kind-4 use (book 5442: "find a door. Click
## on it to open it."; Kimi K30 2026-11-07: the closed doors blocked the corridor and the earned walk). Opcode 1 was not
## entered. The nav prefix with those doors open runs 1931, 1937, then the branch
## at 1943. Region 1932 has no nav link. The rapids stay unmapped.
const KEY := "l19_drain_path"
const DRAIN_SWITCHES := [50, 71, 72]
const BRIDGE := 70
const DOORS := [51, 52]
const DRAIN_REQUIRED := false
const AT_50 := Vector3(1535, 150, -3282)
const AT_71 := Vector3(1622, -10, -3609)
const AT_72 := Vector3(1629, -10, -3246)
const DOOR_AT := Vector3(2550, -100, -854)
const REACH := 20.0
const WALK := [[2557.0, -883.5], [2565.0, -883.5], [2621.5, -883.5]]
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "drain_switches": [], "door_clicked": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 3: return "Invalid drain path state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid drain path state."
	if not (s.get("door_clicked") is bool): return "Invalid drain path state."
	var listed: Variant = s.get("drain_switches")
	if not listed is Array: return "Invalid drain path state."
	var seen: Dictionary = {}
	for id in listed:
		if not (id is int or id is float) or seen.has(int(id)) or not int(id) in DRAIN_SWITCHES: return "Invalid drain path state."
		seen[int(id)] = true
	return ""

static func drain_required() -> bool:
	return DRAIN_REQUIRED

static func moves_doors() -> bool:
	return true

## The door click opens both Golden Doors. Their native kind-4 use toggles open (group 3854, travel 16384) and close (3998), and
## Act 2 saves do not keep native travel, so the open pose is set directly and re-applied after a load while door_clicked is
## true (adapter, same pattern as the L16 greenhouse FireWall doors).
const OPEN_TRAVEL := 16384
func open_doors() -> void:
	var pr: Variant = host.get("progression")
	if pr == null: return
	for id in DOORS:
		if pr.hinges.has(int(id)) and int(pr.travel.get(int(id), 0)) != OPEN_TRAVEL:
			pr.travel[int(id)] = OPEN_TRAVEL
			pr._pose(int(id))

func doors_open() -> bool:
	var pr: Variant = host.get("progression")
	if pr == null: return false
	for id in DOORS:
		if int(pr.travel.get(int(id), 0)) != OPEN_TRAVEL: return false
	return true

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l19_drain_path.gd").new()
	n.host = map
	n.name = "L19DrainPath"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	var switches: Array = []
	var listed: Variant = raw.get("drain_switches", [])
	if listed is Array:
		for id in listed:
			switches.append(int(id))
	return {"version": int(raw.get("version", 1)), "drain_switches": switches, "door_clicked": bool(raw.get("door_clicked", false))}

func drained() -> bool:
	return state().drain_switches.size() == DRAIN_SWITCHES.size()

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func near_drain() -> int:
	if flat_to(AT_50) < REACH: return 50
	if flat_to(AT_71) < REACH: return 71
	if flat_to(AT_72) < REACH: return 72
	return -1

func at_door() -> bool:
	return flat_to(DOOR_AT) < REACH

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 484)
	canvas.add_child(hint)

func _process(_delta: float) -> void:
	hint.text = ""
	if bool(state().door_clicked) and not doors_open(): open_doors()
	if host.flying or not host.starting_magic.world_active(): return
	if at_door() and not bool(state().door_clicked):
		hint.text = "E — Click the door. The drain stays optional."
	elif near_drain() >= 0 and not drained():
		hint.text = "E — Throw this switch. Draining the guck stays optional."

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	var s: Dictionary = state()
	var slot: int = near_drain()
	if slot >= 0 and not slot in s.drain_switches:
		var ids: Array = s.drain_switches
		ids.append(slot)
		s.drain_switches = ids
		host.quest_state[KEY] = s
		get_viewport().set_input_as_handled()
		return
	if at_door() and not bool(s.door_clicked):
		s.door_clicked = true
		host.quest_state[KEY] = s
		open_doors()
		get_viewport().set_input_as_handled()
