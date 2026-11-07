extends Node3D
## STORY-085 (HINTBOOK 5460-5468). Four heads, a level-one Mist of Doom, a demon,
## the Ancients' Stone, and a drag onto the white circle by the red fountain.
## Props 67, 69, 68, and 70 are the rectangle. Prop 66 is the fifth skull.
## No mist command is stored. The level here is the constant 1. Actor 31 is
## IMP_BEL. The hintbook demon stays a separate sentence. No white circle and
## no fountain cstring are stored. The Ancients' Stone opcode 3 is on L20.
## Opcode 18 flags 0x0112 have bit 0x0004 clear, so those words do not move Luther.
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
const KEY := "l19_ghostly_heads"
const HEADS := [67, 69, 68, 70]
const FIFTH := 66
const LIGHT := 65
const DISK := 57
const IMP := 31
const DEMON := -1
const PLATE := -1
const FOUNTAIN := -1
const STONE := -1
const MIST_LEVEL := 1
const AT_67 := Vector3(1451, -130, -1131)
const AT_69 := Vector3(1018, -130, -1128)
const AT_68 := Vector3(1028, -110, -1892)
const AT_70 := Vector3(1451, -110, -1891)
const AT_66 := Vector3(2426, -125, -882)
const IMP_AT := Vector3(1247, -120, -1445)
const REACH := 20.0
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "shot": [], "imp_seen": false, "dragged": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 4: return "Invalid ghostly head state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid ghostly head state."
	if not (s.get("imp_seen") is bool) or not (s.get("dragged") is bool): return "Invalid ghostly head state."
	if s.get("dragged") != false: return "Invalid ghostly head state."
	var listed: Variant = s.get("shot")
	if not listed is Array: return "Invalid ghostly head state."
	var seen: Dictionary = {}
	for id in listed:
		if not (id is int or id is float) or seen.has(int(id)) or not int(id) in HEADS: return "Invalid ghostly head state."
		seen[int(id)] = true
	return ""

static func moves_player() -> bool:
	return false

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l19_ghostly_heads.gd").new()
	n.host = map
	n.name = "L19GhostlyHeads"
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
	return {"version": int(raw.get("version", 1)), "shot": shot, "imp_seen": bool(raw.get("imp_seen", false)), "dragged": false}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func near_head() -> int:
	if flat_to(AT_67) < REACH: return 67
	if flat_to(AT_69) < REACH: return 69
	if flat_to(AT_68) < REACH: return 68
	if flat_to(AT_70) < REACH: return 70
	return -1

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 500)
	canvas.add_child(hint)

func _process(_delta: float) -> void:
	hint.text = ""
	if host.flying or not host.starting_magic.world_active(): return
	if flat_to(IMP_AT) < REACH and not bool(state().imp_seen):
		var seen: Dictionary = state()
		seen.imp_seen = true
		host.quest_state[KEY] = seen
	if near_head() >= 0 and Forms.can_cast(int(host.player_form)):
		hint.text = "E — Level-one Mist of Doom. The demon id stays -1."
	elif flat_to(IMP_AT) < REACH:
		hint.text = "Actor 31 is IMP_BEL. The drag and the fountain stay unplaced."

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if not Forms.can_cast(int(host.player_form)): return
	var head: int = near_head()
	if head < 0 or flat_to(AT_66) < REACH: return
	var s: Dictionary = state()
	var shot: Array = s.shot
	if head in shot: return
	shot.append(head)
	s.shot = shot
	s.dragged = false
	host.quest_state[KEY] = s
	get_viewport().set_input_as_handled()
