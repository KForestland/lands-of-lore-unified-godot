extends Node3D
## STORY-090 (HINTBOOK 5522-5534). Controls 62-67 are Block. Control 62 is the
## westernmost. Record height is -110. Nav floor of region 126 is -30.
## No brick, white ball, or fireball cstring is stored. Props 195, 196, and 197
## are the visible breaks. Opcode 20 was not entered. One blow on control 62
## hacks only the brick. Shared Summon3 breaks the white ball; a blue-bow
## click breaks the fireball. All three stop the pillars (G15 modern adapter).
const KEY := "l20_armory"
const LEFTMOST := 62
const OTHER := 67
const BRICK := 195
const BALL := 196
const FIREBALL := 197
const SOURCES := [195, 196, 197]
const PYRAPOD := -1
const IMP_LEVEL := 3
const BLUE_BOW := "act2:L12_CM:blue_bow"
## Either bow: the City's Dark Bow is the same definition 35 "36-Darkbow" as the Blue Bow (Grok 2026-11-16).
const BOWS := ["act2:L12_CM:blue_bow", "act2:L16_CA:item24"]
## Held from the pack ('Hold in hand') or equipped as the weapon.
func holds_bow() -> bool:
	return str(host.get("hand_item")) in BOWS or str(host.get("equipped_item")) in BOWS
const AT_62 := Vector3(-1375, -30, -1719)
const AT_67 := Vector3(-547, -23, -1726)
const AT_195 := Vector3(-3880, -50, -2630)
const AT_196 := Vector3(-2650, -50, -2924)
const AT_197 := Vector3(-3619, -50, -3431)
const REACH := 20.0
var host: Node3D
var hint: Label
var stage: Label
var sources: Array[MeshInstance3D] = []

static func initial() -> Dictionary:
	return {"version": 1, "hacked": false, "ball": false, "fire": false, "stopped": false}

func stops_pillars() -> bool:
	return bool(state().stopped)

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 5: return "Invalid armory state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid armory state."
	if not (s.get("hacked") is bool) or not (s.get("ball") is bool) or not (s.get("fire") is bool) or not (s.get("stopped") is bool): return "Invalid armory state."
	var hacked: bool = bool(s.get("hacked"))
	if bool(s.get("ball")) and not hacked: return "Invalid armory state."
	if bool(s.get("fire")) and not hacked: return "Invalid armory state."
	if bool(s.get("stopped")) and not (hacked and bool(s.ball) and bool(s.fire)): return "Invalid armory state."
	return ""

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l20_armory.gd").new()
	n.host = map
	n.name = "L20Armory"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	var hacked: bool = bool(raw.get("hacked", false))
	return {"version": int(raw.get("version", 1)), "hacked": hacked, "ball": bool(raw.get("ball", false)) and hacked, "fire": bool(raw.get("fire", false)) and hacked, "stopped": bool(raw.get("stopped", false)) and hacked}

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 548)
	canvas.add_child(hint)
	stage = Label.new()
	stage.name = "Stage"
	stage.position = Vector2(24, 516)
	canvas.add_child(stage)
	var spots: Array[Vector3] = [AT_195, AT_196, AT_197]
	var names: Array[String] = ["Source195", "Source196", "Source197"]
	for index in spots.size():
		sources.append(_box(names[index], spots[index], Color(0.7, 0.7, 0.75)))

func _box(node_name: String, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var box := BoxMesh.new()
	box.size = Vector3(10, 10, 10)
	mesh_node.mesh = box
	mesh_node.position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh_node.material_override = mat
	add_child(mesh_node)
	return mesh_node

func _show() -> void:
	var down: bool = stops_pillars()
	var s := state()
	for index in sources.size():
		sources[index].visible = not bool(s[["hacked","ball","fire"][index]])
	stage.text = "The brick, the white ball, and the fireball break. The pillars stop." if down else ""

func _process(_delta: float) -> void:
	hint.text = ""
	_show()
	if host.flying or not host.starting_magic.world_active(): return
	if flat_to(AT_62) < REACH and not bool(state().hacked):
		hint.text = "E — Hack the spinning brick"
	elif bool(state().hacked) and not bool(state().ball) and aimed_source(AT_196):
		hint.text = "Summon — Ctrl+Q: Ancient Imp at the white ball"
	elif bool(state().hacked) and not bool(state().fire) and aimed_source(AT_197):
		hint.text = "Left click — Loose the bow" if holds_bow() else "A bow meets this fireball."

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active(): return
	if flat_to(AT_62) >= REACH: return
	if int(host.player_form) != 0 or str(host.equipped_item) == "": return
	var s: Dictionary = state()
	if bool(s.hacked): return
	s.hacked = true
	s.stopped = bool(s.ball) and bool(s.fire)
	host.quest_state[KEY] = s
	get_viewport().set_input_as_handled()

## The existing source markers stay at their published adapter positions. Aim
## at their visible upper half (the marker centres are at the native floor).
func aimed_source(point: Vector3) -> bool:
	if host.flying or not host.starting_magic.world_active(): return false
	var target := point + Vector3(0,5,0)
	var origin: Vector3 = host.camera.global_position
	var delta := target-origin
	if delta.length() < 0.01 or delta.length() > 180: return false
	if (-host.camera.global_basis.z).dot(delta.normalized()) <= 0.9: return false
	var query := PhysicsRayQueryParameters3D.create(origin,target,1,[host.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func mark(field: String) -> bool:
	var s := state()
	if not bool(s.hacked) or bool(s[field]): return false
	s[field] = true
	s.stopped = bool(s.hacked) and bool(s.ball) and bool(s.fire)
	host.quest_state[KEY] = s
	_show()
	return true

func accepts_player_spell(id: String) -> bool:
	return id == "summon3" and bool(state().hacked) and not bool(state().ball) and aimed_source(AT_196)

func receive_player_spell(id: String) -> bool:
	return accepts_player_spell(id) and mark("ball")

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless": return
	if not holds_bow() or not aimed_source(AT_197): return
	if mark("fire"): get_viewport().set_input_as_handled()
