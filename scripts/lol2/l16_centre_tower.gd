extends Node3D
## STORY-077 centre tower (HINTBOOK 5250-5268; I08).
## Static Mantle Gate has zero placements, so the door id stays unbound. Actor 45 is
## definition 1282. The L16 def labels do not name Belial, so the fight is not hosted.
## Props 331, 332, 333, and 348 are the mantle rows, event 0. Kind 12 on regions 217
## and 218 stores opcode 18 flags 0x0112. Bit 0x0004 is clear, so Luther stays.
## S01 SECTIONS stays 0. The fourth raising has no stored gate. Movables 84 and 85
## are Jack's Doors north of the bars, not this gate.
const KEY := "l16_centre_tower"
const DOOR_ID := -1
const ACTOR := 45
const ACTOR_DEF := 1282
const MANTLES := [331, 332, 333, 348]
const EXIT_REGIONS := [217, 218]
const NORTH_DOORS := [84, 85]
const HALL := Vector3(5443, 32, 9749)
const ACTOR_AT := Vector3(5522, 32, 7968)
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "at_bars": false, "seen_actor": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 3: return "Invalid centre tower state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid centre tower state."
	if not (s.get("at_bars") is bool) or not (s.get("seen_actor") is bool): return "Invalid centre tower state."
	return ""

static func relocates_player() -> bool:
	return false

static func fight_hosted() -> bool:
	return false

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l16_centre_tower.gd").new()
	n.host = map
	n.name = "L16CentreTower"
	map.add_child(n)
	return n

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

func prior_ready() -> bool:
	var raw: Variant = host.quest_state.get("l16_ne_tower", {})
	if not raw is Dictionary: return false
	return bool(raw.get("at_doors", false))

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
	var ready: bool = prior_ready()
	var at_hall: bool = ready and flat_to(HALL) < 30.0
	var at_actor: bool = ready and flat_to(ACTOR_AT) < 30.0
	if at_hall or at_actor:
		var s: Dictionary = state().duplicate(true)
		var changed: bool = false
		if at_hall and not bool(s.at_bars):
			s.at_bars = true
			changed = true
		if at_actor and not bool(s.seen_actor):
			s.seen_actor = true
			changed = true
		if changed: host.quest_state[KEY] = s
	if at_hall:
		hint.text = "Mantle Gate is not placed. Actor 45's name stays unread. The bars do not move Luther."
	elif at_actor:
		hint.text = "Actor 45 is definition 1282. The fight is not hosted."
