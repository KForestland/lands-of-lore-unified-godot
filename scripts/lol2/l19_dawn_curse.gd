extends Node3D
## STORY-086 and STORY-087 (HINTBOOK 5474-5491). Prop 78 is Dawn good, region 1461.
## Actor 39 is region 2182. No click count is stored. The second E records the curse
## sentence. The third E records the ruby offer and does not grant definition 69.
## Prop 242 is Frank's Placenta, region 262. Belial Birthed has zero placements.
## No curse command is stored. The level is the constant 5. placenta.vqa is not played.
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
const KEY := "l19_dawn_curse"
const PROP := 78
const ACTOR := 39
const DAWN_REGION := 1461
const ACTOR_REGION := 2182
const MOTHER := 242
const MOTHER_REGION := 262
const RUBY_DEFINITION := 69
const RUBY_IDENTITY := 4227368151
const RUBY_HANDLER := 101
const CURSE_AT := 2
const RUBY_AT := 3
const ANCIENT_LEVEL := 5
const CURSE_LINE := "Expel the curse into the mother beast."
const RUBY_COMMENT := "Dawn gives Luther Ruby and vanishes."
const SCENE_NAME := "placenta.vqa"
const SCENE_OFFSET := 5066703
const IN_MOVIE_TABLE := false
const BIRTHED_PLACEMENTS := 0
const DEMONS := -1
const DOOR := -1
const DAWN_AT := Vector3(2802, -1000, -882)
const ACTOR_AT := Vector3(1939, -125, -891)
const MOTHER_AT := Vector3(-1160, -20, -4258)
const REACH := 30.0
var host: Node3D
var hint: Label
var cast_level: int = 5

static func initial() -> Dictionary:
	return {"version": 1, "clicks": 0, "curse_said": false, "ruby_offered": false, "line": "", "glob_entered": false, "demons_killed": false}

static func accepts_level(level: int) -> bool:
	return level == ANCIENT_LEVEL

static func grants_ruby() -> bool:
	return false

static func plays_movie() -> bool:
	return false

static func relocates_player() -> bool:
	return false

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 7: return "Invalid dawn curse state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid dawn curse state."
	var clicks: Variant = s.get("clicks")
	if not (clicks is int or clicks is float) or int(clicks) < 0 or int(clicks) > RUBY_AT: return "Invalid dawn curse state."
	if not (s.get("curse_said") is bool) or not (s.get("ruby_offered") is bool): return "Invalid dawn curse state."
	if not (s.get("glob_entered") is bool) or not (s.get("demons_killed") is bool): return "Invalid dawn curse state."
	if s.get("demons_killed") != false: return "Invalid dawn curse state."
	var line: Variant = s.get("line")
	if not line is String: return "Invalid dawn curse state."
	var n: int = int(clicks)
	var said: bool = bool(s.get("curse_said"))
	var offered: bool = bool(s.get("ruby_offered"))
	if said != (n >= CURSE_AT): return "Invalid dawn curse state."
	if offered != (n >= RUBY_AT): return "Invalid dawn curse state."
	if said and str(line) != CURSE_LINE: return "Invalid dawn curse state."
	if not said and str(line) != "": return "Invalid dawn curse state."
	if bool(s.get("glob_entered")) and not said: return "Invalid dawn curse state."
	return ""

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l19_dawn_curse.gd").new()
	n.host = map
	var label: String = "L19DawnCurse" if str(map.area_id) == "L19_BC" else "L20MotherCurse"
	n.name = label
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	var clicks: int = int(raw.get("clicks", 0))
	var said: bool = bool(raw.get("curse_said", false))
	var line: String = CURSE_LINE if said else ""
	return {"version": int(raw.get("version", 1)), "clicks": clicks, "curse_said": said, "ruby_offered": bool(raw.get("ruby_offered", false)) and clicks >= RUBY_AT, "line": line, "glob_entered": bool(raw.get("glob_entered", false)) and said, "demons_killed": false}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 516)
	canvas.add_child(hint)

func _process(_delta: float) -> void:
	hint.text = ""
	if host.flying or not host.starting_magic.world_active(): return
	if str(host.area_id) == "L19_BC" and flat_to(DAWN_AT) < REACH:
		hint.text = "E — keep clicking Dawn. The curse line is not a stored cstring."
	elif str(host.area_id) == "L20_BB" and flat_to(MOTHER_AT) < REACH and bool(state().curse_said):
		hint.text = "E — ancient-magic level 5. placenta.vqa stays unplayed."

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if str(host.area_id) == "L19_BC":
		_click_dawn()
	elif str(host.area_id) == "L20_BB":
		_cast_curse()

func _click_dawn() -> void:
	if flat_to(DAWN_AT) >= REACH: return
	var s: Dictionary = state()
	if int(s.clicks) >= RUBY_AT: return
	s.clicks = int(s.clicks) + 1
	if int(s.clicks) >= CURSE_AT:
		s.curse_said = true
		s.line = CURSE_LINE
	if int(s.clicks) >= RUBY_AT:
		s.ruby_offered = true
	s.demons_killed = false
	host.quest_state[KEY] = s
	get_viewport().set_input_as_handled()

func _cast_curse() -> void:
	if not bool(state().curse_said): return
	if not Forms.can_cast(int(host.player_form)): return
	if not accepts_level(cast_level): return
	if flat_to(MOTHER_AT) >= REACH: return
	var s: Dictionary = state()
	s.glob_entered = true
	s.demons_killed = false
	host.quest_state[KEY] = s
	get_viewport().set_input_as_handled()
