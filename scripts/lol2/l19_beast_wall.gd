extends Node3D
## STORY-080 red strands (HINTBOOK 5383-5398; I14; I23).
## No strand cstring and no frond cstring exist on L17 or L19. I23 names the birth
## scene and the last video only, and neither is this beast scene. L17 stores
## hw01.vqa, hw12.vqa, and hw14.vqa. Those names were not joined to a movie number.
## No arrival selector is filed as the beast scene. This module does not play a
## movie and does not move Luther.
const KEY := "l19_beast_wall"
const STRAND_ID := -1
const FROND_ID := -1
const MOVIE := -1
const ARRIVAL_SELECTOR := -1
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "noted": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 2: return "Invalid beast wall state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid beast wall state."
	if not (s.get("noted") is bool): return "Invalid beast wall state."
	return ""

static func plays_movie() -> bool:
	return false

static func relocates_player() -> bool:
	return false

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l19_beast_wall.gd").new()
	n.host = map
	n.name = "L19BeastWall"
	map.add_child(n)
	return n

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

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
	if not bool(state().noted):
		var s: Dictionary = state().duplicate(true)
		s.noted = true
		host.quest_state[KEY] = s
	hint.text = "The west-wall strands are not placed. No beast movie is stored. Luther stays."
