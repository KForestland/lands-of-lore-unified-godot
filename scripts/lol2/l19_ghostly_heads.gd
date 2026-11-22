extends Node3D
## STORY-085 (HINTBOOK 5460-5468). Four heads, a level-one Mist of Doom, a demon,
## the Ancients' Stone, and a drag onto the white circle by the red fountain.
## Props 67, 69, 68, and 70 are the rectangle. Prop 66 is the fifth skull.
## No mist command is stored. The shared learned Mists1 cast replaces the E adapter. Actor 31 is
## IMP_BEL. The hintbook demon stays a separate sentence. No white circle and
## no fountain cstring are stored, so the circle, the fountain, and the token
## are adapters. The Ancients' Stone opcode 3 stays on L20. Opcode 18 flags
## 0x0112 have bit 0x0004 clear, so those words do not move Luther.
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
const KEY := "l19_ghostly_heads"
const HEADS := [67, 69, 68, 70]
const FIFTH := 66
const LIGHT := 65
const DISK := 57
const IMP := 31
const DEMON := -1
const PLATE := -1
const FOUNTAIN := -1
const STONE := -1
const MIST_LEVEL := 1
const AT_67 := Vector3(1451, -130, -1131)
const AT_69 := Vector3(1018, -130, -1128)
const AT_68 := Vector3(1028, -110, -1892)
const AT_70 := Vector3(1451, -110, -1891)
const AT_66 := Vector3(2426, -125, -882)
const IMP_AT := Vector3(1247, -120, -1445)
const CIRCLE_AT := Vector3(1240, -110, -1600)
const FOUNTAIN_AT := Vector3(1240, -110, -1680)
const REACH := 20.0
var host: Node3D
var hint: Label
var stage: Label
var token: MeshInstance3D

static func initial() -> Dictionary:
	return {"version": 1, "shot": [], "imp_seen": false, "dragged": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 4: return "Invalid ghostly head state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid ghostly head state."
	if not (s.get("imp_seen") is bool) or not (s.get("dragged") is bool): return "Invalid ghostly head state."
	var listed: Variant = s.get("shot")
	if not listed is Array: return "Invalid ghostly head state."
	var seen: Dictionary = {}
	for id in listed:
		if not (id is int or id is float) or seen.has(int(id)) or not int(id) in HEADS: return "Invalid ghostly head state."
		seen[int(id)] = true
	if bool(s.get("dragged")) and seen.size() != HEADS.size(): return "Invalid ghostly head state."
	return ""

static func moves_player() -> bool:
	return false

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l19_ghostly_heads.gd").new()
	n.host = map
	n.name = "L19GhostlyHeads"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	var shot: Array = []
	var listed: Variant = raw.get("shot", [])
	if listed is Array:
		for id in listed:
			shot.append(int(id))
	var dragged: bool = bool(raw.get("dragged", false)) and shot.size() == HEADS.size()
	return {"version": int(raw.get("version", 1)), "shot": shot, "imp_seen": bool(raw.get("imp_seen", false)), "dragged": dragged}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func near_head() -> int:
	if flat_to(AT_67) < REACH: return 67
	if flat_to(AT_69) < REACH: return 69
	if flat_to(AT_68) < REACH: return 68
	if flat_to(AT_70) < REACH: return 70
	return -1

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 500)
	canvas.add_child(hint)
	stage = Label.new()
	stage.name = "Stage"
	stage.position = Vector2(24, 468)
	canvas.add_child(stage)
	_box("WhiteCircle", CIRCLE_AT, Color(0.9, 0.9, 0.9))
	_box("RedFountain", FOUNTAIN_AT, Color(0.7, 0.05, 0.05))
	token = _box("SkullToken", IMP_AT, Color(0.85, 0.85, 0.7))

func _box(node_name: String, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var box := BoxMesh.new()
	box.size = Vector3(8, 8, 8)
	mesh_node.mesh = box
	mesh_node.position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh_node.material_override = mat
	add_child(mesh_node)
	return mesh_node

func _show() -> void:
	var dragged: bool = bool(state().dragged)
	token.position = CIRCLE_AT if dragged else IMP_AT
	stage.text = "The demon's body lies on the white circle by the red fountain." if dragged else ""

func _process(_delta: float) -> void:
	hint.text = ""
	_show()
	if host.flying or not host.starting_magic.world_active(): return
	if flat_to(IMP_AT) < REACH and not bool(state().imp_seen):
		var seen: Dictionary = state()
		seen.imp_seen = true
		host.quest_state[KEY] = seen
	if near_head() >= 0 and Forms.can_cast(int(host.player_form)):
		hint.text = "Mists — Q: Lesser Apparitions at the head"
	elif flat_to(IMP_AT) < REACH:
		hint.text = "The demon of the heads. Its body belongs on the white circle."

func accepts_player_spell(id: String) -> bool:
	return id == "mists1" and near_head() in HEADS and near_head() not in state().shot

func receive_player_spell(id: String) -> bool:
	if not accepts_player_spell(id) or host.flying or not host.starting_magic.world_active(): return false
	if not Forms.can_cast(int(host.player_form)): return false
	var head := near_head()
	var s: Dictionary = state()
	s.shot.append(head)
	s.dragged = s.shot.size() == HEADS.size()
	host.quest_state[KEY] = s
	_show()
	return true

## Modern first-needed lesson. The existing head-use reach and its actual
## floor band keep the lesson in this room; learning never records a shot.
func needs_mists_lesson()->bool:
	var head:=near_head()
	if head<0 or bool(state().dragged):return false
	var floor_height:float={67:AT_67.y,69:AT_69.y,68:AT_68.y,70:AT_70.y}[head]
	return absf(host.player.global_position.y-32.0-floor_height)<=24.0
