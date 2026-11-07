extends Node3D
## STORY-080 follow-up (HINTBOOK 5383-5398).
## No strand or frond cstring on L17, L19, or L20. This form-feed count puts Prima
## pages 150-151 on the secret storeroom. The strand paragraph is that count's
## printed 164. The review card's printed 160 stays a separate count. I33 frames
## g_00365 (291:40) and g_00375 (296:40) do not name strands. The nearest stored
## L17 .vqa cstring to the exit command at file offset 4810641 is hw01.vqa at
## 652134. movie_table.json does not list that name. This module records it and
## does not play it. T04's L19 module stays the gap note.
const KEY := "l17_beast_blade"
const STRAND_ID := -1
const FROND_ID := -1
const WEST_AT := Vector3(-5632, 32, 5803.5)
const REACH := 30.0
const SCENE_NAME := "hw01.vqa"
const SCENE_OFFSET := 652134
const EXIT_COMMAND_OFFSET := 4810641
const HW01_EARLIER := 143215
const HW12_OFFSET := 182068
const HW14_OFFSET := 195069
const IN_MOVIE_TABLE := false
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "cut": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 2: return "Invalid beast blade state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid beast blade state."
	if not (s.get("cut") is bool): return "Invalid beast blade state."
	return ""

static func plays_movie() -> bool:
	return false

static func relocates_player() -> bool:
	return false

static func nearest_gap() -> int:
	return EXIT_COMMAND_OFFSET - SCENE_OFFSET

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l17_beast_blade.gd").new()
	n.host = map
	n.name = "L17BeastBlade"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	return {"version": int(raw.get("version", 1)), "cut": bool(raw.get("cut", false))}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func at_wall() -> bool:
	return flat_to(WEST_AT) < REACH

func blade_ready() -> bool:
	return int(host.player_form) == 0 and str(host.equipped_item) != ""

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 436)
	canvas.add_child(hint)

func _process(_delta: float) -> void:
	hint.text = ""
	if host.flying or not host.starting_magic.world_active(): return
	if not at_wall(): return
	if bool(state().cut):
		hint.text = "hw01.vqa is recorded and not played. Luther stays."
	elif blade_ready():
		hint.text = "E — Cut the west wall with a blade"
	else:
		hint.text = "The west wall wants a blade in Human form."

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if not at_wall() or not blade_ready() or bool(state().cut): return
	var s: Dictionary = state()
	s.cut = true
	host.quest_state[KEY] = s
	get_viewport().set_input_as_handled()
