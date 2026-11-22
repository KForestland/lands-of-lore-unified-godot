extends Node3D
## STORY-071 SE tower oil (HINTBOOK 4911-4936; I04). Prop 392 is the oil fountain.
## An aimed click or a spark marks it burned. Dormant item row 24 then shows as the Dark Bow.
## act2:L12_CM:blue_bow stays in the pack. The head statue has no placement on this strip.
## Kind 9 group 14558 on prop 392 (DECODED): opcode 1 byte 4 = 100 stores the angle word on
## mode-1 movables 98, 81, and 80 (travel 150, 100, 40), opcode 198 stores local 11 = 1, and
## opcode 9 arm 0x15 enqueues prop 608. The spark's word0 is not in the export. The record mask
## is 0x0011 and byte +8 is 1, so the burn admits a hit with that mask and dword_26 at most 1.
## The drain mesh still shows with the flame. It is not the door motion.
const KEY := "l16_se_oil"
const FOUNTAIN_RECORD := 392
const FOUNTAIN := Vector3(-2201, -5, 12864)
const BOW := "act2:L16_CA:item24"
const BLUE := "act2:L12_CM:blue_bow"
const DOORS := [80, 81, 98]
## angle_word * 100 / 100 on mode 1. Fraction travel/angle_word is 1, so each panel slides fully open.
const DOOR_TRAVEL := {80: 40, 81: 100, 98: 150}
var host: Node3D
var hint: Label
var body: StaticBody3D
var flame: MeshInstance3D
var drain: MeshInstance3D
var fire_results: Array = []

class Receiver:
	extends RefCounted
	var owner: Node
	func _init(n: Node): owner = n
	func receive_spark() -> bool: return owner.burn("spark")
	func receive_spark_level(_level: int) -> bool: return owner.burn("spark")

static func initial() -> Dictionary:
	return {"version": 1, "burned": false}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 2: return "Invalid SE oil state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid SE oil state."
	if not s.get("burned") is bool: return "Invalid SE oil state."
	return ""

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l16_se_oil.gd").new()
	n.host = map
	n.name = "L16SeOil"
	map.add_child(n)
	return n

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

func _ready() -> void:
	body = StaticBody3D.new()
	body.position = FOUNTAIN
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("spark_receiver", Receiver.new(self))
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 28.0
	shape.shape = sphere
	body.add_child(shape)
	add_child(body)
	flame = MeshInstance3D.new()
	flame.name = "OilFlame"
	var box := BoxMesh.new()
	box.size = Vector3(10, 18, 10)
	flame.mesh = box
	flame.position = FOUNTAIN + Vector3(0, 22, 0)
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(0.85, 0.35, 0.05)
	flame.material_override = hot
	add_child(flame)
	drain = MeshInstance3D.new()
	drain.name = "DrainMouth"
	var drain_box := BoxMesh.new()
	drain_box.size = Vector3(18, 6, 18)
	drain.mesh = drain_box
	drain.position = FOUNTAIN + Vector3(0, -8, 24)
	var wet := StandardMaterial3D.new()
	wet.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wet.albedo_color = Color(0.15, 0.35, 0.55)
	drain.material_override = wet
	drain.visible = false
	add_child(drain)
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 420)
	canvas.add_child(hint)
	restore()

func _pose_fire_doors() -> void:
	var pr = host.progression
	if pr == null: return
	for id in DOORS:
		var word: int = int(DOOR_TRAVEL[id])
		if pr.hinges.has(id) and int(pr.travel.get(id, 0)) != word:
			pr.travel[id] = word
			pr._pose(id)

func restore() -> void:
	var burned: bool = bool(state().burned)
	body.collision_layer = 0 if burned else 1
	flame.visible = burned
	drain.visible = burned
	if burned: _pose_fire_doors()
	var items = host.get_node_or_null("Act2WorldItems")
	if items == null: return
	var sprite = items.sprites.get(BOW)
	if sprite == null: return
	var collected: Array = host.quest_state.get("act2_items", {}).get("collected", [])
	var taken: bool = BOW in collected
	var show_bow: bool = burned and not taken
	sprite.visible = show_bow

func aimed(point: Vector3, reach: float) -> bool:
	if not host.starting_magic.world_active() or host.flying: return false
	var d: Vector3 = point - host.camera.global_position
	if d.length() < 0.01 or d.length() >= reach: return false
	return (-host.camera.global_basis.z).dot(d.normalized()) > 0.9

func burn(_how: String) -> bool:
	if state().burned or not host.starting_magic.world_active(): return false
	var admit: Dictionary = {"word0": 0x0011, "word2": 0, "dword_26": 0, "global_23331": 0, "context": "prop:392"}
	fire_results = host.progression.fire("prop:%d" % FOUNTAIN_RECORD, 9, admit)
	var s: Dictionary = state().duplicate(true)
	s.burned = true
	host.quest_state[KEY] = s
	restore()
	host.save_feedback("The oil on the fountain catches.")
	return true

func _process(_delta: float) -> void:
	hint.text = ""
	if not state().burned and aimed(FOUNTAIN, 180.0):
		hint.text = "Left click — Ignite the oil"
	restore()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not state().burned and aimed(FOUNTAIN, 180.0) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if burn("melee"): get_viewport().set_input_as_handled()
