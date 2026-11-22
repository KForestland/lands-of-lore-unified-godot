extends Node3D
## BK04 L17 beast-scene carry (STORY-080).
## Region 1293 kind 12 event 2 runs group 1566 with no predicate. Opcode 12
## byte 4 is 37 (stem hive4_). Opcode 18 is kind 1, target u16 0, flags 0x0005,
## words (-6084, -6404, 0), heading 18386. Routine 0x65BB0 takes the direct
## path because bit 0x0004 is set: the signed words at +4 and +6 are an absolute
## position, and the target u16 is not read. Bit 0x0100 is clear, so the height
## word is not written. The return-2 player path then stands on the destination
## region's floor. Those words are region 1259, floor 0, on the cavern side of
## the pit. Regions 1279-1314 have no neighbour link to that side.
## Hintbook 5383-5398: cut the strands on the exit room's west wall, enter the
## scene, and come out able to reach Belial's Laboratory. g_00362 is that maw
## with the HUD gone. HIVE4.MIX is not opened and hw01.vqa stays off the table.
## A Human with a blade at region 1271 is posed in region 1292, inside the exit
## block, on the path to region 1312 that does not enter 1293. Entering 1293
## poses Luther on the stored words.
const KEY := "l17_beast_carry"
const GROUP := 1566
const TRIGGER_REGION := 1293
const POCKET_REGION := 1271
const LAND_REGION := 1292
const READER_REGION := 1259
const TARGET := 0
const FLAGS := 0x0005
const HEADING_UNITS := 18386
const WORD_X := -6084
const WORD_Y := -6404
const POCKET_AT := Vector3(-6212.0, 32.0, 6264.25)
const LAND_AT := Vector3(-6064.5, 32.0, 5904.0)
const READER_AT := Vector3(-6084.0, 32.0, 6404.0)
const REACH := 30.0
const EXIT_LO := 1279
const EXIT_HI := 1314
var host: Node3D
var hint: Label
var stage: Label
var reader_latched: bool = false

static func initial() -> Dictionary:
	return {"version": 1, "carried": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 2: return "Invalid beast carry state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid beast carry state."
	if not (s.get("carried") is bool): return "Invalid beast carry state."
	return ""

static func relocates_player() -> bool:
	return true

static func direct_relocation() -> bool:
	return (FLAGS & 0x0004) != 0 and (FLAGS & 0x0100) == 0

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l17_beast_carry.gd").new()
	n.host = map
	n.name = "L17BeastCarry"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	return {"version": int(raw.get("version", 1)), "carried": bool(raw.get("carried", false))}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func at_pocket() -> bool:
	return flat_to(POCKET_AT) < REACH

func blade_ready() -> bool:
	return int(host.player_form) == 0 and str(host.equipped_item) != ""

func region_here() -> int:
	var shift := Vector3.ZERO
	var raw: Variant = host.get("native_translation")
	if raw is Vector3:
		shift = raw as Vector3
	return int(host.progression.region_at(host.player.global_position - shift))

func pose(at: Vector3, heading: bool) -> void:
	host.player.velocity = Vector3.ZERO
	host.player.global_position = at
	if heading:
		host.player.rotation.y = -TAU * float(HEADING_UNITS) / 65536.0

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 452)
	canvas.add_child(hint)
	stage = Label.new()
	stage.name = "Stage"
	stage.position = Vector2(24, 428)
	canvas.add_child(stage)

func _process(_delta: float) -> void:
	hint.text = ""
	if bool(state().carried):
		stage.text = "The beast carries you out."
	if host.flying or not host.starting_magic.world_active(): return
	if not at_pocket(): return
	if bool(state().carried):
		hint.text = stage.text
	elif blade_ready():
		hint.text = "E — Cut the red strands"
	else:
		hint.text = "The red strands want a blade in Human form."

func _physics_process(_delta: float) -> void:
	if host.flying or not host.starting_magic.world_active(): return
	var here: int = region_here()
	if here != TRIGGER_REGION:
		reader_latched = false
		return
	if reader_latched: return
	reader_latched = true
	pose(READER_AT, true)
	print("CARRY region 1293 group 1566 poses ", READER_AT, " heading ", HEADING_UNITS)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if not at_pocket() or not blade_ready() or bool(state().carried): return
	var s: Dictionary = state()
	s.carried = true
	host.quest_state[KEY] = s
	pose(LAND_AT, false)
	print("CARRY pocket cut poses ", LAND_AT, " in the exit block")
	get_viewport().set_input_as_handled()
