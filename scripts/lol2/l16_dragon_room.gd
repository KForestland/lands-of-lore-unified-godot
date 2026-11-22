extends Node3D
## STORY-078 dragon room (HINTBOOK 5269-5288; I09).
## Prop 241 is the Dragon. Prop 211 is the Dragon Statue and is not the chop.
## Control 74 is the telepad. Byte 0x31 is the PROVEN split in act2_progression.gd:
## level 17, arrival selector 1, L17_HC pose native (1434, 7075), region 131.
## Kind 5 value 4 fires when the support owner changes. ADA30 admits value 4 for every form.
## After the chop, standing within 40 of the pad calls use_exit once. That distance stands in
## for the support-owner change. This module does not move Luther itself. No door id is stored.
## U16 73 fits more than one table, so the blood plate is not toggled. The mantle item
## is unplaced, and I09 says the telepad command does not store that test.
## Kind 9 group 6384 is the chop (mask 0x0002, mode 4, predicate 206). The left click admits
## word0 0x0002, dword_26 0, and global 0x23331 0. The player swing does not export that word.
## The chop flag is set only when group 6384 runs. Opcode 9 arm 0x15 enqueues u16 73 and does
## not assign it a door id.
const KEY := "l16_dragon_room"
const DRAGON := 241
const STATUE := 211
const TELEPAD := 74
const DOOR_ID := -1
const PAD_BYTE := 0x31
const DEST_LEVEL := 17
const DEST_SELECTOR := 1
const DEST_AREA := "L17_HC"
const DRAGON_AT := Vector3(1625, 52, 4417)
const CHOP_GROUP := 6384
## Kind 9 record 0a09f018020000000104. Mask +4 is 0x0002. The port strike word does not share that bit.
const ADMIT_WORD0 := 0x0002
var fire_results: Array = []
const STATUE_AT := Vector3(261, 50, 10600)
const PAD := Vector3(2100, 15, 4296)
const DEST_POSE := Vector3(1434, 32, -7075)
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "chopped": false, "pad_seen": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 3: return "Invalid dragon room state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid dragon room state."
	if not (s.get("chopped") is bool) or not (s.get("pad_seen") is bool): return "Invalid dragon room state."
	return ""

static func apply_chop(s: Dictionary, record: int) -> Dictionary:
	if record != DRAGON or bool(s.get("chopped", false)): return s
	var nxt: Dictionary = s.duplicate(true)
	nxt.chopped = true
	return nxt

static func apply_pad(s: Dictionary) -> Dictionary:
	if not bool(s.get("chopped", false)) or bool(s.get("pad_seen", false)): return s
	var nxt: Dictionary = s.duplicate(true)
	nxt.pad_seen = true
	return nxt

static func relocates_player() -> bool:
	return false

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l16_dragon_room.gd").new()
	n.host = map
	n.name = "L16DragonRoom"
	map.add_child(n)
	return n

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

func aimed(point: Vector3, reach: float) -> bool:
	if not host.starting_magic.world_active() or host.flying: return false
	var d: Vector3 = point - host.camera.global_position
	if d.length() < 0.01 or d.length() >= reach: return false
	return (-host.camera.global_basis.z).dot(d.normalized()) > 0.9

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	var flat := Vector2(p.x - point.x, p.z - point.z)
	return flat.length()

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 420)
	canvas.add_child(hint)

func _process(_delta: float) -> void:
	hint.text = ""
	if host.flying or not host.starting_magic.world_active(): return
	var on_pad: bool = bool(state().chopped) and flat_to(PAD) < 40.0
	if on_pad and not bool(state().pad_seen):
		host.quest_state[KEY] = apply_pad(state())
		var progression: Variant = host.get("progression")
		if progression != null and progression.has_method("use_exit"):
			progression.use_exit("control:%d" % TELEPAD)
	if not bool(state().chopped) and aimed(DRAGON_AT, 180.0):
		hint.text = "Left click — Chop the dragon"
	elif aimed(STATUE_AT, 180.0):
		hint.text = "The statue is not the dragon."
	elif on_pad:
		hint.text = "The telepad opens the caverns."

func chop() -> bool:
	if bool(state().chopped) or not host.starting_magic.world_active(): return false
	var progression: Variant = host.get("progression")
	if progression == null or not progression.has_method("fire"): return false
	var admit: Dictionary = {
		"word0": ADMIT_WORD0,
		"word2": 0,
		"dword_26": 0,
		"global_23331": 0,
		"context": "prop:%d" % DRAGON,
	}
	fire_results = progression.fire("prop:%d" % DRAGON, 9, admit)
	var ran: bool = false
	for row in fire_results:
		if int(row.get("group", -1)) == CHOP_GROUP and str(row.get("status", "")) == "ran":
			ran = true
	if not ran: return false
	host.quest_state[KEY] = apply_chop(state(), DRAGON)
	host.save_feedback("The dragon falls; its blood opens the way.")
	return true

## Headless has no window, so a captured mouse cannot stick. A real window still requires it.
func _player_click() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	if not _player_click() or bool(state().chopped): return
	if not aimed(DRAGON_AT, 180.0): return
	if chop(): get_viewport().set_input_as_handled()
