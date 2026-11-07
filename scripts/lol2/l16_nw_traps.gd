extends Node3D
## STORY-072 NW tower traps (HINTBOOK 4824-4841; I05). Prop 88 is the Block trap, prop 89 the
## Fire trap, prop 90 the Ice trap. A click breaks the brick. The carried blue bow, in hand,
## breaks the fireball and stays in the pack. A spark of charge 3 or more breaks the ice ball.
## Hintbook 4831-4832 names a third-level summoned imp or a pyrapod-altered spark fireball.
## Neither piece is hosted: the cast table is spark and heal, and pyrapod handler group 32
## stays UNKNOWN. The charge test is the logged adapter. Brady printed 233 names other
## weapons; those checks stay off this module. Props 641 and 600
## stay. FireWall doors 86, 87, and 88 stay shut. The battlement floors stay put.
const KEY := "l16_nw_traps"
const BRICK := 88
const FIRE := 89
const ICE := 90
const BLUE := "act2:L12_CM:blue_bow"
const BRICK_AT := Vector3(-10576, 100, -750)
const FIRE_AT := Vector3(-10442, 125, -1838)
const ICE_AT := Vector3(-8868, 125, -3286)
const DOORS := [86, 87, 88]
var host: Node3D
var hint: Label
var bodies: Dictionary = {}

class IceReceiver:
	extends RefCounted
	var owner: Node
	func _init(n: Node): owner = n
	func receive_spark() -> bool: return false
	func receive_spark_level(level: int) -> bool: return owner.break_ice(int(level))

static func initial() -> Dictionary:
	return {"version": 1, "brick": false, "fireball": false, "ice": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 4: return "Invalid NW trap state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid NW trap state."
	if not s.get("brick") is bool or not s.get("fireball") is bool or not s.get("ice") is bool: return "Invalid NW trap state."
	return ""

static func accepts_fire(hand: String) -> bool:
	return hand == BLUE

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l16_nw_traps.gd").new()
	n.host = map
	n.name = "L16NwTraps"
	map.add_child(n)
	return n

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

func _add_body(record: int, at: Vector3, ice: bool) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	if ice: body.set_meta("spark_receiver", IceReceiver.new(self))
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 30.0
	shape.shape = sphere
	body.add_child(shape)
	add_child(body)
	bodies[record] = body

func _ready() -> void:
	_add_body(BRICK, BRICK_AT, false)
	_add_body(FIRE, FIRE_AT, false)
	_add_body(ICE, ICE_AT, true)
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 420)
	canvas.add_child(hint)
	restore()

func _shown(record: int, shown: bool) -> void:
	var row: Variant = host.prop_placements.get(record)
	if not row is Array: return
	var basis: Basis = Basis() if shown else Basis().scaled(Vector3.ZERO)
	(row[0] as MultiMesh).set_instance_transform(int(row[1]), Transform3D(basis, row[2]))

func restore() -> void:
	var s := state()
	var brick_up: bool = not bool(s.brick)
	var fire_up: bool = not bool(s.fireball)
	var ice_up: bool = not bool(s.ice)
	_shown(BRICK, brick_up)
	_shown(FIRE, fire_up)
	_shown(ICE, ice_up)
	bodies[BRICK].collision_layer = 1 if brick_up else 0
	bodies[FIRE].collision_layer = 1 if fire_up else 0
	bodies[ICE].collision_layer = 1 if ice_up else 0

func aimed(point: Vector3, reach: float) -> bool:
	if not host.starting_magic.world_active() or host.flying: return false
	var d: Vector3 = point - host.camera.global_position
	if d.length() < 0.01 or d.length() >= reach: return false
	return (-host.camera.global_basis.z).dot(d.normalized()) > 0.9

func _mark(field: String, line: String) -> bool:
	if not host.starting_magic.world_active(): return false
	if bool(state()[field]): return false
	var s: Dictionary = state().duplicate(true)
	s[field] = true
	host.quest_state[KEY] = s
	restore()
	host.save_feedback(line)
	return true

func break_brick() -> bool:
	if not aimed(BRICK_AT, 180.0): return false
	return _mark("brick", "The brick breaks.")

func break_fire() -> bool:
	if not aimed(FIRE_AT, 180.0): return false
	if not accepts_fire(str(host.hand_item)): return false
	return _mark("fireball", "The blue bow breaks the fireball.")

func break_ice(level: int) -> bool:
	if level < 3: return false
	return _mark("ice", "The white ball breaks.")

func _process(_delta: float) -> void:
	hint.text = ""
	var s := state()
	if not bool(s.brick) and aimed(BRICK_AT, 180.0): hint.text = "Left click — Strike the brick"
	elif not bool(s.fireball) and aimed(FIRE_AT, 180.0) and accepts_fire(str(host.hand_item)): hint.text = "Left click — Loose the blue bow"
	elif not bool(s.fireball) and aimed(FIRE_AT, 180.0): hint.text = "The blue bow meets this fireball."
	elif not bool(s.ice) and aimed(ICE_AT, 180.0): hint.text = "A level-three spark breaks the white ball."
	restore()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if break_brick() or break_fire(): get_viewport().set_input_as_handled()
