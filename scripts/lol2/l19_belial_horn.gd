extends Node3D
## STORY-081 (HINTBOOK 5410-5413). Prop 222 carries opcode 3 identity 0x0CBE2C90,
## definition 22, name 23-Hrn Belial. L19 item count is 0, so the horn is not a
## placed row. Actor 32 is BELSTAT in region 616. The pipe is region 687. Those
## regions stay unjoined. No death flag is stored, so this grant is not timed.
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
const REACH := 40.0
const DEATH_FLAG := false
var host: Node3D
var hint: Label

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
	return flat_to(PIPE_AT) < REACH

func take() -> bool:
	if bool(state().taken) or not at_pipe() or death_stored(): return false
	if not ITEM in host.carried_collected and host.carried_collected.size() >= 64: return false
	var packet: Dictionary = host.quest_state.get("act2_items", Items.initial()).duplicate(true)
	var collected: Variant = packet.get("collected")
	if not collected is Array: return false
	if not ITEM in collected:
		collected.append(ITEM)
	packet.collected = collected
	host.quest_state.act2_items = packet
	if not ITEM in host.carried_collected:
		host.carried_collected.append(ITEM)
	Items.sync(host)
	var s: Dictionary = state()
	s.taken = true
	host.quest_state[KEY] = s
	return true

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 452)
	canvas.add_child(hint)

func _process(_delta: float) -> void:
	hint.text = ""
	if host.flying or not host.starting_magic.world_active() or not at_pipe(): return
	if bool(state().taken):
		hint.text = "Belial's Horn is carried. No death flag was stored."
	else:
		hint.text = "E — Take Belial's Horn. Baccata has no placement."

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if take():
		get_viewport().set_input_as_handled()
