extends Node3D
## STORY-077 centre tower (HINTBOOK 5250-5268; I08).
## Static Mantle Gate is slot 57 and has zero placements, so DOOR_ID stays -1.
## There is no door. The bars are props 331, 332, 333, and 348 (template Mantle).
## Kind 12 event 2 on regions 216, 217 and 218 (groups 0, 188 and 376, byte-identical), runs when local 12
## (Mantle_conveyed) is 0. Opcode 198 would store 1 and opcode 18 would move the
## four props, flags 0x0112, height word 40. Bit 0x0004 is clear, so Luther stays.
## The group does not run: opcode 199 has no handler. Opcode 2 arm 0x34 and opcode 9
## arm 0x1B on kind-4 target 22 were not entered. Standing in either region poses the
## props to those stored words and stores local 12. An unset local 12 reads as 0.
## The box, the disk, and the yellow figure have no template or static name and no
## row in the four corner towers. Tower Hole (slot 64) has zero placements. City
## Push/Pull controls 71, 107, and 108 are not those towers.
## Actor 45 is definition 1282. E in Human form with a weapon drops the foe.
## foe_down and conveyed are optional so a size-3 save still loads.
## S01 SECTIONS stays 0. Movables 84 and 85 are Jack's Doors, not this gate.
const KEY := "l16_centre_tower"
const DOOR_ID := -1
const ACTOR := 45
const ACTOR_DEF := 1282
const MANTLES := [331, 332, 333, 348]
const EXIT_REGIONS := [216, 217, 218]
const NORTH_DOORS := [84, 85]
const HALL := Vector3(5443, 32, 9749)
const ACTOR_AT := Vector3(5522, 32, 7968)
const PLACED_H := 10.0
const BARS := Vector3(5511, 32, 9888)
var host: Node3D
var hint: Label
var stage: Label
var foe: MeshInstance3D

static func initial() -> Dictionary:
	return {"version": 1, "at_bars": false, "seen_actor": false, "conveyed": false}

static func pose_for(id: int) -> Vector3:
	match id:
		331: return Vector3(5334, 40, 9622)
		332: return Vector3(5713, 40, 9617)
		333: return Vector3(5809, 40, 9893)
		348: return Vector3(5201, 40, 9893)
	return Vector3.ZERO

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary: return "Invalid centre tower state."
	var state: Dictionary = s
	if state.size() < 3 or state.size() > 5: return "Invalid centre tower state."
	for key in state.keys():
		var name := str(key)
		if name != "version" and name != "at_bars" and name != "seen_actor" and name != "foe_down" and name != "conveyed":
			return "Invalid centre tower state."
	if not state.has("version") or not state.has("at_bars") or not state.has("seen_actor"): return "Invalid centre tower state."
	var version: Variant = state.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid centre tower state."
	if not (state.get("at_bars") is bool) or not (state.get("seen_actor") is bool): return "Invalid centre tower state."
	if state.has("foe_down") and not (state.get("foe_down") is bool): return "Invalid centre tower state."
	if state.has("conveyed") and not (state.get("conveyed") is bool): return "Invalid centre tower state."
	if bool(state.get("foe_down", false)) and not bool(state.get("seen_actor")): return "Invalid centre tower state."
	return ""

static func relocates_player() -> bool:
	return false

static func fight_hosted() -> bool:
	return true

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l16_centre_tower.gd").new()
	n.host = map
	n.name = "L16CentreTower"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	var seen: bool = bool(raw.get("seen_actor", false))
	return {
		"version": int(raw.get("version", 1)),
		"at_bars": bool(raw.get("at_bars", false)),
		"seen_actor": seen,
		"foe_down": bool(raw.get("foe_down", false)) and seen,
		"conveyed": bool(raw.get("conveyed", false)),
	}

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
	stage = Label.new()
	stage.name = "Stage"
	stage.position = Vector2(24, 388)
	canvas.add_child(stage)
	foe = _box("FoeBody", ACTOR_AT, Color(0.55, 0.15, 0.15))

func _box(node_name: String, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var box := BoxMesh.new()
	box.size = Vector3(12, 24, 8)
	mesh_node.mesh = box
	mesh_node.position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh_node.material_override = mat
	add_child(mesh_node)
	return mesh_node

func _show() -> void:
	var down: bool = bool(state().foe_down)
	foe.visible = not down
	stage.text = "The guard falls." if down else ""

func _apply_pose(conveyed: bool) -> void:
	var placements: Variant = host.get("prop_placements")
	if not placements is Dictionary: return
	for id in MANTLES:
		var row: Variant = (placements as Dictionary).get(id)
		if not row is Array: continue
		var entry: Array = row
		var at: Vector3 = entry[2]
		var origin := at
		if conveyed:
			var dest: Vector3 = pose_for(int(id))
			origin = Vector3(dest.x, at.y + (dest.y - PLACED_H), dest.z)
		var multi: MultiMesh = entry[0]
		multi.set_instance_transform(int(entry[1]), Transform3D(Basis(), origin))

func _local12() -> int:
	var prog: Variant = host.get("progression")
	if prog == null: return 0
	var native: Variant = prog.get("native")
	if native == null: return 0
	var locals: Variant = native.get("locals")
	if not locals is Dictionary or not (locals as Dictionary).has(12): return 0
	return int((locals as Dictionary)[12])

func _ensure_local() -> void:
	var prog: Variant = host.get("progression")
	if prog == null: return
	var native: Variant = prog.get("native")
	if native == null: return
	var locals: Variant = native.get("locals")
	if locals is Dictionary and int((locals as Dictionary).get(12, -1)) == 1: return
	native.call("set_local", 12, 1)

func _region() -> int:
	var prog: Variant = host.get("progression")
	if prog == null: return -1
	return int(prog.get("current_region"))

func _process(_delta: float) -> void:
	_show()
	var conveyed: bool = bool(state().conveyed)
	if conveyed:
		_apply_pose(true)
		_ensure_local()
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
	if not conveyed and _region() in EXIT_REGIONS and _local12() == 0:
		var next: Dictionary = state().duplicate(true)
		next.conveyed = true
		next.at_bars = true
		host.quest_state[KEY] = next
		_ensure_local()
		_apply_pose(true)
		conveyed = true
	if conveyed and (_region() in EXIT_REGIONS or at_hall):
		hint.text = "The bars are raised as far as they go."
	elif at_hall:
		hint.text = "Bars close the hall."
	elif at_actor and not bool(state().foe_down):
		hint.text = "E — Fight the guard (Human form, weapon in hand)"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if host.flying or not host.starting_magic.world_active() or not prior_ready(): return
	if flat_to(ACTOR_AT) >= 30.0: return
	if int(host.player_form) != 0 or str(host.equipped_item) == "": return
	var s: Dictionary = state()
	if bool(s.foe_down): return
	s.seen_actor = true
	s.foe_down = true
	host.quest_state[KEY] = s
	get_viewport().set_input_as_handled()
