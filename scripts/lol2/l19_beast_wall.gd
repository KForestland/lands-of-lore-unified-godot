extends Node3D
## STORY-080 red strands (HINTBOOK 5383-5398; I14; I23).
## No strand cstring and no frond cstring exist on L17 or L19. I23 names the birth
## scene and the last video only, and neither is this beast scene. L17 stores
## hw01.vqa, hw12.vqa, and hw14.vqa. Those names were not joined to a movie number.
## The beast arrival is the witnessed L19 selector 1 at (84, 22, 305), nav region 25.
## The strand, the frond, and the card are adapters. Luther takes one step only there.
## A reload does not move him again. Another L19 entry does not. hw01.vqa is a different beat.
const KEY := "l19_beast_wall"
const STRAND_ID := -1
const FROND_ID := -1
const MOVIE := -1
const ARRIVAL_SELECTOR := 1
const ARRIVAL_REGION := 25
const ARRIVAL_AT := Vector3(84, 22, 305)
const ARRIVAL_REACH := 48.0
const STEP_AT := Vector3(84, 22, 80)
var host: Node3D
var hint: Label
var stage: Label

static func initial() -> Dictionary:
	return {"version": 1, "noted": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 2: return "Invalid beast wall state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid beast wall state."
	if not (s.get("noted") is bool): return "Invalid beast wall state."
	return ""

static func plays_movie() -> bool:
	return true

static func relocates_player() -> bool:
	return true

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
	stage = Label.new()
	stage.name = "Stage"
	stage.position = Vector2(24, 388)
	canvas.add_child(stage)
	_box("RedStrand", Vector3(40, 22, 305), Color(0.7, 0.1, 0.1))
	_box("BeastFrond", Vector3(120, 22, 305), Color(0.15, 0.45, 0.15))

func _box(node_name: String, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var box := BoxMesh.new()
	box.size = Vector3(8, 20, 8)
	mesh_node.mesh = box
	mesh_node.position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh_node.material_override = mat
	add_child(mesh_node)
	return mesh_node

func _at_arrival() -> bool:
	if int(host.start_selector) != ARRIVAL_SELECTOR: return false
	if not bool(host.get("arrived_by_level_change")): return false
	var here: Vector3 = host.player.global_position
	if Vector2(here.x - ARRIVAL_AT.x, here.z - ARRIVAL_AT.z).length() > ARRIVAL_REACH: return false
	var progression: Node = host.get("progression")
	if progression == null or not progression.has_method("region_at"): return false
	return int(progression.region_at(here)) == ARRIVAL_REGION

func _process(_delta: float) -> void:
	hint.text = ""
	if host.flying or not host.starting_magic.world_active(): return
	if not bool(state().noted) and _at_arrival():
		var s: Dictionary = state().duplicate(true)
		s.noted = true
		host.quest_state[KEY] = s
		host.player.position = STEP_AT
	if not bool(state().noted): return
	stage.text = "You are drawn into the beast and step through."
	hint.text = stage.text
