extends Node3D
## STORY-079 Subterranean Caverns (HINTBOOK 5363-5378; I14).
## Four level-change owners. I14 left byte 5 unread. act2_progression.gd already
## splits opcode-2 arm 0x1C as level = byte & 0x1F and selector = byte >> 5.
## Regions 1312 and 1313, byte 0x33, are level 19 arrival 1 (L19_BC).
## Movable 50, byte 0x50, is level 16 arrival 2 (L16_CA). Region 1318, byte 0x70,
## is level 16 arrival 3 (L16_CA). This module records the region and does not
## change the scene. Killing is optional and nothing is spawned. Opcode 18 on
## region 1293, target u16 0, flags 0x0005, stays unused.
const KEY := "l17_cavern_run"
const KILL_REQUIRED := false
const FORWARD_REGIONS := [1312, 1313]
const FORWARD_BYTE := 0x33
const FORWARD_LEVEL := 19
const FORWARD_SELECTOR := 1
const CIRCLE := 50
const CIRCLE_BYTE := 0x50
const CIRCLE_LEVEL := 16
const CIRCLE_SELECTOR := 2
const SIDE_REGION := 1318
const SIDE_BYTE := 0x70
const SIDE_LEVEL := 16
const SIDE_SELECTOR := 3
const IGNORED_REGION := 1293
const FORWARD_AT := Vector3(-5436, 32, 5802)
const SOUTH_AT := Vector3(-5436, 32, 5849.5)
const CIRCLE_AT := Vector3(1439, 17, -7256)
const SIDE_AT := Vector3(8347.5, 2, 2235)
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "exit_region": -1}

static func decode(byte: int) -> Vector2i:
	return Vector2i(byte & 0x1F, byte >> 5)

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 2: return "Invalid cavern run state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid cavern run state."
	var region: Variant = s.get("exit_region")
	if not (region is int or region is float): return "Invalid cavern run state."
	return ""

static func relocates_player() -> bool:
	return false

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l17_cavern_run.gd").new()
	n.host = map
	n.name = "L17CavernRun"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	return {"version": int(raw.get("version", 1)), "exit_region": int(raw.get("exit_region", -1))}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	var flat := Vector2(p.x - point.x, p.z - point.z)
	return flat.length()

func reached() -> int:
	if flat_to(FORWARD_AT) < 30.0: return 1312
	if flat_to(SOUTH_AT) < 30.0: return 1313
	if flat_to(CIRCLE_AT) < 30.0: return CIRCLE
	if flat_to(SIDE_AT) < 30.0: return SIDE_REGION
	return -1

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
	var region: int = reached()
	if region < 0: return
	if int(state().exit_region) != region:
		var s: Dictionary = state()
		s.exit_region = region
		host.quest_state[KEY] = s
	if region == 1312 or region == 1313:
		hint.text = "Killing stays optional. Regions 1312 and 1313 decode to level 19, arrival 1. Luther stays."
	else:
		hint.text = "Killing stays optional. This exit stays on the progression host. Luther stays."
