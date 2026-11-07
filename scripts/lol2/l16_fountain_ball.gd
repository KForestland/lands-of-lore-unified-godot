extends Node3D
## NOT ATTACHED (lead correction 2026-11-05): prop 602 is the NE greenhouse fireball (STORY-070), not the dry-fountain ball;
## the lichen placements are the greenhouse planters. Kept as a draft for STORY-070; the dry-fountain ball is unidentified (Grok H22).
## STORY-068 southern dry fountain (Prima p.146, hintbook 4800-4815): the ball floating over the raised dry fountain is
## destroyed by any means; it cracks open, water returns to the city, and black lichen grows in lumps; take nine.
## Native: prop 602 (template 61, native (2289,648), height 18) is the ball; its kind-10 record runs group 37776
## (opcode 2 arm 0x0C, opcode 9 kind 4, opcode 15, opcode 1 on movables 92/93/94 = 100, opcode 9 self arg 2).
## The 14 Lichen props (opcode 3 identity 0xCA4DEBCC, definition 122) grow through a puddle/local-4 cycle whose producer
## is not traced. Adapters (DEVIATIONS): Spark (any level) or an aimed melee left click breaks the ball; once broken
## every lichen placement is shown and E takes it (one Black Lichen each, persistent receipts).
const KEY := "l16_fountain_ball"
const BALL_RECORD := 602
const BALL := Vector3(2289, 70, -648)
const LICHEN := [518,521,522,527,528,533,534,539,540,545,546,551,552,557]
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
var host: Node3D
var hint: Label
var body: StaticBody3D

class Receiver:
	extends RefCounted
	var owner: Node
	func _init(n: Node): owner = n
	func receive_spark() -> bool: return owner.break_ball("spark")
	func receive_spark_level(_level: int) -> bool: return owner.break_ball("spark")

static func initial() -> Dictionary: return {"version":1,"broken":false,"taken":[]}
static func validate(s: Variant, quests: Dictionary) -> String:
	if not s is Dictionary or s.size() != 3 or s.get("version") != 1 or not s.get("broken") is bool or not s.get("taken") is Array: return "Invalid fountain ball state."
	for r in s.taken:
		if not (r is int or r is float) or int(r) not in LICHEN: return "Invalid lichen receipt."
	if not s.broken and not s.taken.is_empty(): return "Lichen taken before the ball broke."
	return ""
static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l16_fountain_ball.gd").new(); n.host = map; n.name = "L16FountainBall"; map.add_child(n); return n

func state() -> Dictionary: return host.quest_state.get(KEY, initial())

func _ready() -> void:
	body = StaticBody3D.new(); body.position = BALL; body.collision_layer = 1; body.collision_mask = 0
	body.set_meta("spark_receiver", Receiver.new(self))
	var shape := CollisionShape3D.new(); var sphere := SphereShape3D.new(); sphere.radius = 34.0; shape.shape = sphere; body.add_child(shape); add_child(body)
	var canvas := CanvasLayer.new(); canvas.layer = 34; add_child(canvas); hint = Label.new(); hint.position = Vector2(24,420); canvas.add_child(hint)
	restore()

func _set_shown(record: int, shown: bool) -> void:
	var row: Variant = host.prop_placements.get(record)
	if not row is Array: return
	var multi: MultiMesh = row[0]
	multi.set_instance_transform(int(row[1]), Transform3D(Basis() if shown else Basis().scaled(Vector3.ZERO), row[2]))

func restore() -> void:
	var s := state()
	_set_shown(BALL_RECORD, not s.broken)
	body.collision_layer = 0 if s.broken else 1
	for r in LICHEN: _set_shown(r, s.broken and r not in s.taken.map(func(v): return int(v)))

func aimed(point: Vector3, reach: float) -> bool:
	if not host.starting_magic.world_active() or host.flying: return false
	var d: Vector3 = point - host.camera.global_position
	return d.length() < reach and d.length() > 0.01 and (-host.camera.global_basis.z).dot(d.normalized()) > 0.95

func break_ball(how: String) -> bool:
	if state().broken or not host.starting_magic.world_active(): return false
	var s := state().duplicate(true); s.broken = true; host.quest_state[KEY] = s
	host.progression.fire("prop:%d" % BALL_RECORD, 10, {})
	restore()
	host.save_feedback("The ball cracks open and water flows back into the city. Black lichen grows around the fountain.")
	return true

func lichen_aimed() -> int:
	if not state().broken: return -1
	var taken: Array = state().taken.map(func(v): return int(v))
	for r in LICHEN:
		if r in taken: continue
		var row: Variant = host.prop_placements.get(r)
		if row is Array and aimed((row[2] as Vector3) + Vector3.UP * 20, 110.0): return r
	return -1

func take(record: int) -> Dictionary:
	if record not in LICHEN or not state().broken or record in state().taken.map(func(v): return int(v)): return {"ok":false,"reason":"Nothing to take."}
	if host.carried_collected.size() >= 64: return {"ok":false,"reason":"Make room for the lichen."}
	var id := "act2:L16_CA:lichen%d" % record
	var s := state().duplicate(true); s.taken.append(record); host.quest_state[KEY] = s
	host.carried_collected.append(id); Items.sync(host)
	if not id in host.quest_state.act2_items.collected: host.quest_state.act2_items.collected.append(id)
	restore()
	return {"ok":true,"reason":"Black Lichen (%d taken)." % s.taken.size()}

func _process(_delta: float) -> void:
	hint.text = ""
	if not state().broken and aimed(BALL, 200.0): hint.text = "Left click — Strike the floating ball"
	elif lichen_aimed() >= 0: hint.text = "E — Take black lichen"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not state().broken and aimed(BALL, 200.0) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if break_ball("melee"): get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		var r := lichen_aimed()
		if r >= 0: host.save_feedback(take(r).reason); get_viewport().set_input_as_handled()
