extends Node3D
## STORY-068 southern dry fountain (HINTBOOK 4788-4814, H22). Prop 210, template 5, native (440, -10438),
## height 85, region 9806. It has no events. An aimed melee click or a spark hides the orb, shows a water
## plane on the pad, and grows nine black-lichen clumps. Prop 602, group 37776, and the 14 greenhouse
## planters are not used. The nine clumps are an adapter: no producer for this pad was read.
const KEY := "l16_dry_fountain"
const BALL_RECORD := 210
const ORB := Vector3(440, 85, 10438)
const CLUMPS := 9
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
const LICHEN_AT := [
	Vector3(420, 70, 10410), Vector3(438, 70, 10410), Vector3(456, 70, 10410),
	Vector3(420, 70, 10436), Vector3(456, 70, 10436),
	Vector3(420, 70, 10462), Vector3(438, 70, 10462), Vector3(456, 70, 10462),
	Vector3(430, 70, 10448),
]
var host: Node3D
var hint: Label
var body: StaticBody3D
var water: MeshInstance3D
var clumps: Array = []

class Receiver:
	extends RefCounted
	var owner: Node
	func _init(n: Node): owner = n
	func receive_spark() -> bool: return owner.break_orb("spark")
	func receive_spark_level(_level: int) -> bool: return owner.break_orb("spark")

static func initial() -> Dictionary: return {"version": 1, "broken": false, "water": false, "taken": []}
static func clump_id(index: int) -> String: return "act2:L16_CA:pad_lichen%d" % index
static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 4 or s.get("version") != 1: return "Invalid dry fountain state."
	if not s.get("broken") is bool or not s.get("water") is bool or not s.get("taken") is Array: return "Invalid dry fountain state."
	if bool(s.broken) != bool(s.water): return "Dry fountain water does not follow the break."
	var seen: Dictionary = {}
	for r in s.taken:
		if not (r is int or r is float) or int(r) < 0 or int(r) >= CLUMPS or seen.has(int(r)): return "Invalid dry fountain clump."
		seen[int(r)] = true
	if not s.broken and not s.taken.is_empty(): return "Lichen taken before the orb broke."
	return ""
static func apply_break(s: Dictionary) -> Dictionary:
	if s.broken: return s
	var n: Dictionary = s.duplicate(true)
	n.broken = true
	n.water = true
	return n
static func apply_take(s: Dictionary, index: int) -> Dictionary:
	if not s.broken or index < 0 or index >= CLUMPS: return s
	for r in s.taken:
		if int(r) == index: return s
	var n: Dictionary = s.duplicate(true)
	n.taken.append(index)
	return n
static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l16_dry_fountain.gd").new()
	n.host = map
	n.name = "L16DryFountain"
	map.add_child(n)
	return n

func state() -> Dictionary: return host.quest_state.get(KEY, initial())

func _ready() -> void:
	body = StaticBody3D.new()
	body.position = ORB
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("spark_receiver", Receiver.new(self))
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 34.0
	shape.shape = sphere
	body.add_child(shape)
	add_child(body)
	water = MeshInstance3D.new()
	water.name = "PadWater"
	var plane := SurfaceTool.new()
	plane.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quad := [Vector3(400, 52, 10488), Vector3(477, 52, 10488), Vector3(477, 52, 10384), Vector3(400, 52, 10384)]
	for i in [0, 1, 2, 0, 2, 3]: plane.add_vertex(quad[i])
	plane.generate_normals()
	water.mesh = plane.commit()
	var wet := StandardMaterial3D.new()
	wet.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wet.albedo_color = Color(0.05, 0.25, 0.38)
	wet.cull_mode = BaseMaterial3D.CULL_DISABLED
	water.material_override = wet
	add_child(water)
	for index in CLUMPS:
		var clump := MeshInstance3D.new()
		clump.name = "PadLichen%d" % index
		var box := BoxMesh.new()
		box.size = Vector3(8, 12, 8)
		clump.mesh = box
		clump.position = LICHEN_AT[index]
		var dark := StandardMaterial3D.new()
		dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dark.albedo_color = Color(0.02, 0.02, 0.02)
		clump.material_override = dark
		add_child(clump)
		clumps.append(clump)
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 420)
	canvas.add_child(hint)
	restore()

func _set_orb(shown: bool) -> void:
	var row: Variant = host.prop_placements.get(BALL_RECORD)
	if not row is Array: return
	var basis := Basis() if shown else Basis().scaled(Vector3.ZERO)
	(row[0] as MultiMesh).set_instance_transform(int(row[1]), Transform3D(basis, row[2]))

func restore() -> void:
	var s := state()
	_set_orb(not s.broken)
	body.collision_layer = 0 if s.broken else 1
	water.visible = s.broken
	var taken: Dictionary = {}
	for r in s.taken: taken[int(r)] = true
	for index in clumps.size():
		var show_clump: bool = s.broken and not taken.has(index)
		clumps[index].visible = show_clump

func aimed(point: Vector3, reach: float) -> bool:
	if not host.starting_magic.world_active() or host.flying: return false
	var d: Vector3 = point - host.camera.global_position
	if d.length() < 0.01 or d.length() >= reach: return false
	return (-host.camera.global_basis.z).dot(d.normalized()) > 0.9

func break_orb(how: String) -> bool:
	if state().broken or not host.starting_magic.world_active(): return false
	host.quest_state[KEY] = apply_break(state())
	restore()
	host.save_feedback("The ball cracks open and water flows back into the fountain. Black lichen grows on the pad. (%s)" % how)
	return true

func clump_aimed() -> int:
	if not state().broken: return -1
	var taken: Dictionary = {}
	for r in state().taken: taken[int(r)] = true
	for index in CLUMPS:
		if taken.has(index): continue
		if aimed(LICHEN_AT[index] + Vector3.UP * 12, 110.0): return index
	return -1

func take(index: int) -> Dictionary:
	var nxt := apply_take(state(), index)
	if nxt == state() or nxt.taken == state().taken: return {"ok": false, "reason": "Nothing to take."}
	if host.carried_collected.size() >= 64: return {"ok": false, "reason": "Make room for the lichen."}
	var id := clump_id(index)
	host.quest_state[KEY] = nxt
	host.carried_collected.append(id)
	Items.sync(host)
	if not host.quest_state.act2_items.collected.has(id): host.quest_state.act2_items.collected.append(id)
	restore()
	return {"ok": true, "reason": "Black Lichen (%d taken)." % nxt.taken.size()}

func _process(_delta: float) -> void:
	hint.text = ""
	if not state().broken and aimed(ORB, 200.0): hint.text = "Left click — Strike the floating ball"
	elif clump_aimed() >= 0: hint.text = "E — Take black lichen"
	restore()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not state().broken and aimed(ORB, 200.0) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if break_orb("melee"): get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	var r := clump_aimed()
	if r < 0: return
	host.save_feedback(str(take(r).reason))
	get_viewport().set_input_as_handled()
