extends Node3D
## STORY-082 (HINTBOOK 5414-5427). Human breaks the bars, Lizard enters the gutter,
## Human shoots three slots. Bar door has zero placements. No gutter volume is
## stored. Switches 74, 75, and 76 are the decoded slots. Their record regions
## are 36, 34, and 32. The stored points fall in nav region 30. Movable 77 is
## the Sewer door. Opcode 1 and opcode 196 were not entered, so it does not move.
## No opcode tests Human or Lizard. Form 0 is Human. Form 2 is Lizard.
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
const KEY := "l19_sewer_forms"
const BARS := -1
const GUTTER := -1
const SWITCHES := [74, 75, 76]
const RECORD_REGIONS := [36, 34, 32]
const NAV_REGION := 30
const DOOR := 77
const AT_74 := Vector3(-323, 30, -2124)
const AT_75 := Vector3(-304, 30, -2124)
const AT_76 := Vector3(-281, 30, -2124)
const DOOR_AT := Vector3(-344, -40, -1621)
const REACH := 12.0
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "lizard_at_wall": false, "switches": []}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 3: return "Invalid sewer form state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid sewer form state."
	if not (s.get("lizard_at_wall") is bool): return "Invalid sewer form state."
	var listed: Variant = s.get("switches")
	if not listed is Array: return "Invalid sewer form state."
	var seen: Dictionary = {}
	for id in listed:
		if not (id is int or id is float) or seen.has(int(id)) or not int(id) in SWITCHES: return "Invalid sewer form state."
		seen[int(id)] = true
	return ""

static func bars_breakable(_form: int) -> bool:
	return false

static func gutter_enterable(_form: int) -> bool:
	return false

static func moves_door() -> bool:
	return false

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l19_sewer_forms.gd").new()
	n.host = map
	n.name = "L19SewerForms"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	var switches: Array = []
	var listed: Variant = raw.get("switches", [])
	if listed is Array:
		for id in listed:
			switches.append(int(id))
	return {"version": int(raw.get("version", 1)), "lizard_at_wall": bool(raw.get("lizard_at_wall", false)), "switches": switches}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func near_switch() -> int:
	if flat_to(AT_74) < REACH: return 74
	if flat_to(AT_75) < REACH: return 75
	if flat_to(AT_76) < REACH: return 76
	return -1

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 468)
	canvas.add_child(hint)

func _process(_delta: float) -> void:
	hint.text = ""
	if host.flying or not host.starting_magic.world_active(): return
	var slot: int = near_switch()
	if slot < 0: return
	var form: int = int(host.player_form)
	var s: Dictionary = state()
	if form == 2:
		if not bool(s.lizard_at_wall):
			s.lizard_at_wall = true
			host.quest_state[KEY] = s
		hint.text = "Lizard at the switch wall. The gutter id is -1."
		return
	if form != 0 or not Forms.can_use_weapon(form):
		hint.text = "The three slots stay for Human form."
		return
	var ids: Array = s.switches
	if not slot in ids:
		ids.append(slot)
		s.switches = ids
		host.quest_state[KEY] = s
	hint.text = "Human at switch %d. The bars stay unplaced." % slot
