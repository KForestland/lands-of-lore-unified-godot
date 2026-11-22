extends Node3D
const Grants=preload("res://scripts/lol2/item_grants.gd")
## STORY-081 (HINTBOOK 5410-5413). Prop 222 carries opcode 3 identity 0x0CBE2C90,
## definition 22, name 23-Hrn Belial. L19 item count is 0, so the horn is not a
## placed row. Actor 32 is BELSTAT in region 616. The pipe is region 687. Those
## regions stay unjoined. No death flag is stored, so this grant is not timed.
## The caption names Baccata's death as the book's link. It is not a decoded flag.
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
const KEY := "l19_belial_horn"
const PROP := 222
const ACTOR := 32
const ACTOR_REGION := 616
const PIPE_REGION := 687
const ITEM := "act2:L19_BC:horn"
const DEFINITION := 22
const IDENTITY := 213789840
const PIPE_AT := Vector3(120, 0, 525)
# Original prop222 billboard has bottom0/top91; aim at its visible centre.
const AIM := PIPE_AT+Vector3.UP*45.5
## The pipe stands beyond an 80-unit shaft south of the arrival corridor (BJ10 2026-11-09: a player walking to PIPE_AT falls
## 390 units); the rim where the player stops and looks down the shaft takes the E as well.
const RIM_AT := Vector3(120, 0, 350)
const REACH := 40.0
const DEATH_FLAG := false
var host: Node3D
var hint: Label
var stage: Label

static func initial() -> Dictionary:
	return {"version": 1, "taken": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 2: return "Invalid horn state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid horn state."
	if not (s.get("taken") is bool): return "Invalid horn state."
	return ""

static func death_stored() -> bool:
	return DEATH_FLAG

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l19_belial_horn.gd").new()
	n.host = map
	n.name = "L19BelialHorn"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	return {"version": int(raw.get("version", 1)), "taken": bool(raw.get("taken", false))}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func at_pipe() -> bool:
	return flat_to(PIPE_AT) < REACH or flat_to(RIM_AT) < REACH

func take() -> bool:
	if bool(state().taken) or not at_pipe() or death_stored(): return false
	if not ITEM in host.carried_collected and host.carried_collected.size() >= 64: return false
	var collected: Variant = host.quest_state.get("act2_items", Items.initial()).get("collected")
	if not collected is Array: return false
	if not Grants.grant(host,ITEM,{"cap":false,"duplicate":"skip","history":"act2_once","sync":true}).ok: return false
	var s: Dictionary = state()
	s.taken = true
	host.quest_state[KEY] = s
	return true

const TAKEN_LINE := "Baccata is dead. You carry Belial's Horn: back along the corridor to the barred door."
func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 452)
	canvas.add_child(hint)
	stage = Label.new()
	stage.name = "Stage"
	stage.position = Vector2(24, 420)
	canvas.add_child(stage)

func _process(_delta: float) -> void:
	hint.text = ""
	# Grok 2026-11-16 19:34Z (MISSING DIRECTION): after the horn nothing named the way on; the line also still said the horn
	# lay by the pipe. The earned road (c10_l19a_route) goes back along the corridor to the barred door.
	if bool(state().taken):
		stage.text = TAKEN_LINE
	if host.flying or not host.starting_magic.world_active() or not at_pipe(): return
	if bool(state().taken):
		hint.text = TAKEN_LINE
	else:
		hint.text = "E — Take Belial's Horn"

func generic_target() -> Dictionary:
	if host.flying or not host.starting_magic.world_active() or bool(state().taken) or not at_pipe():return {}
	return {"point":AIM}
func try_use() -> bool:
	if generic_target().is_empty():return false
	return take()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if take():
		get_viewport().set_input_as_handled()
