extends Node3D
## STORY-069 and STORY-076, NE tower (HINTBOOK 4842-4847 and 5224-5236; I01, I02, I03, I10).
## FireWall doors 92-94 are the opened entrance from the greenhouse. The creature graph stops on
## region 6079. Region 3107 stores opcode 18 words (16082, -3886), flags 0x0c04, target u16 0.
## I03 files that target as not the player. The lift that carries Luther to ARRIVAL
## is an adapter against that decode, logged as such. Tower Hole, the box, and the
## yellow eight-sided figure have zero placements. Prop 615 stays at height -999.
## The move happens once, when at_doors flips.
## Control 74, the one placed Telepad, stays on the dragon room.
const KEY := "l16_ne_tower"
const DOORS := [92, 93, 94]
const LIP_REGION := 6079
const DOOR := Vector3(2292, 40, -2950)
const ARRIVAL := Vector3(16082, 132, 3886) # Floor 100 plus the form-0 foot offset. y 100 drops the capsule through the floor.
const TOWER_RECORD := 615
const SECTIONS := 0
var host: Node3D
var hint: Label
var stage: Label

static func initial() -> Dictionary:
	return {"version": 1, "at_doors": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 2: return "Invalid NE tower state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid NE tower state."
	if not s.get("at_doors") is bool: return "Invalid NE tower state."
	return ""

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l16_ne_tower.gd").new()
	n.host = map
	n.name = "L16NeTower"
	map.add_child(n)
	return n

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

func relocates_player() -> bool:
	return true

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 420)
	canvas.add_child(hint)
	stage = Label.new()
	stage.name = "Stage"
	stage.position = Vector2(24, 388)
	canvas.add_child(stage)

func doors_open() -> bool:
	return bool(host.quest_state.get("l16_greenhouse", {}).get("opened", false))

func near_doors() -> bool:
	if not host.starting_magic.world_active() or host.flying: return false
	var p: Vector3 = host.player.global_position
	var flat := Vector2(p.x - DOOR.x, p.z - DOOR.z)
	return flat.length() < 30.0

func _process(_delta: float) -> void:
	hint.text = ""
	var near: bool = near_doors()
	var open_row: bool = doors_open()
	if near and open_row and not bool(state().at_doors):
		var s: Dictionary = state().duplicate(true)
		s.at_doors = true
		host.quest_state[KEY] = s
		host.player.position = ARRIVAL
	if bool(state().at_doors):
		var line := "The lift carries you up."
		stage.text = line
		hint.text = line
