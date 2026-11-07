extends Node3D
## L14 quill passage. Prop 344, native (2211, 5110), height 125.
## Opcode 196 words: region 1614 floor 100, ceiling 200, region 4197 ceiling 190, all speed 10.
## The library node already owns those meshes and uses different words (-40, +20, +100).
## This writer runs after that node and only while its exit flag is false.
## Both 4197 ceilings share one node, so +10 puts 180 on 190 and 130 on 140.
## Sound 975 is cbalopn1.aud. Playback stays off. Predicate operator 4 was not entered.
## Brady printed page 116 is the spark-then-click gate. The two seconds are the library adapter timer.
const KEY: String = "l14_quill"
const INKWELL := Vector3(2211, 125, -5110)
const LAMPS := {343: Vector3(1888, 130, -5032), 350: Vector3(1888, 130, -5136)}
const DELTAS := {"1614:floor": -30.0, "1614:ceiling": 20.0, "4197:ceiling": 10.0}
const REACH := 64.0
const MOTION := 2.0
const SOUND_ID := 975
const SOUND_NAME := "cbalopn1.aud"
const OP20_PLAYED := false
var host: Node3D

class Receiver:
	extends RefCounted
	var owner: Node
	var id: int
	func _init(node: Node, lamp: int) -> void:
		owner = node
		id = lamp
	func receive_spark() -> bool:
		return owner.spark(id)
	func receive_spark_level(_level: int) -> bool:
		return owner.spark(id)

static func initial() -> Dictionary:
	return {"version": 1, "lit": [], "opened": false, "elapsed": 0.0}

static func validate(saved: Variant, quests: Dictionary) -> String:
	if not quests is Dictionary: return "Invalid quill passage."
	if not saved is Dictionary or saved.size() != 4 or int(saved.get("version", 0)) != 1: return "Invalid quill passage."
	if not saved.get("opened") is bool: return "Invalid quill passage."
	var elapsed: Variant = saved.get("elapsed")
	if not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or float(elapsed) < 0.0 or float(elapsed) > MOTION:
		return "Invalid quill passage."
	if not saved.get("lit") is Array: return "Invalid quill passage."
	var seen: Array = []
	for raw in saved.lit:
		var id := int(raw)
		if id != 343 and id != 350: return "Invalid quill passage."
		if id in seen: return "Invalid quill passage."
		seen.append(id)
	if bool(saved.opened) and seen.size() != 2: return "Invalid quill passage."
	if not bool(saved.opened) and float(elapsed) != 0.0: return "Invalid quill passage."
	return ""

static func attach(map: Node3D) -> Node:
	var node: Node = load("res://scripts/lol2/l14_quill.gd").new()
	node.host = map
	node.name = "L14Quill"
	map.add_child(node)
	return node

func state() -> Dictionary:
	var saved: Dictionary = host.quest_state.get(KEY, initial())
	return saved.duplicate(true)

func _ready() -> void:
	process_physics_priority = -1
	for id in LAMPS:
		var body := StaticBody3D.new()
		body.position = LAMPS[id]
		body.collision_mask = 0
		body.set_meta("spark_receiver", Receiver.new(self, int(id)))
		add_child(body)
		var box := BoxShape3D.new()
		box.size = Vector3(28, 38, 28)
		var shape := CollisionShape3D.new()
		shape.shape = box
		body.add_child(shape)

func active() -> bool:
	if int(host.get("player_form") if host.get("player_form") != null else 0) != 0: return false
	if host.get("flying") == true: return false
	var magic: Variant = host.get("starting_magic")
	if magic != null and magic.has_method("world_active") and not magic.world_active(): return false
	return true

func spark(id: int) -> bool:
	if not active(): return false
	if id != 343 and id != 350: return false
	var saved := state()
	var lit: Array = []
	for raw in saved.lit:
		lit.append(int(raw))
	if id in lit: return true
	lit.append(id)
	saved.lit = lit
	host.quest_state[KEY] = saved
	return true

func flat_distance() -> float:
	var delta: Vector3 = host.player.global_position - INKWELL
	return Vector2(delta.x, delta.z).length()

func both_lit(saved: Dictionary) -> bool:
	var seen := {}
	for raw in saved.lit:
		seen[int(raw)] = true
	return seen.has(343) and seen.has(350)

func use() -> bool:
	if host.get_tree() != null and host.get_tree().paused: return false
	if host.get("flying") == true: return false
	if flat_distance() > REACH: return false
	var saved := state()
	if not both_lit(saved):
		if host.has_method("save_feedback"): host.save_feedback("The lamps are dark.")
		return false
	if not bool(saved.opened):
		saved.opened = true
		saved.elapsed = 0.0
		host.quest_state[KEY] = saved
		if host.has_method("save_feedback"): host.save_feedback("The quill opens a passage.")
	return true

func library() -> Node:
	return host.get_node_or_null("L14Library")

func apply_parts() -> void:
	var lib := library()
	if lib == null or not lib.get("exit_parts") is Dictionary: return
	if lib.has_method("state") and bool(lib.state().get("exit", false)): return
	var saved := state()
	if not bool(saved.opened): return
	var span := float(saved.elapsed) / MOTION
	var parts: Dictionary = lib.exit_parts
	for key in DELTAS:
		if not parts.has(key): continue
		var node: Node3D = parts[key]
		node.position.y = float(DELTAS[key]) * span

func _physics_process(delta: float) -> void:
	if host == null: return
	var saved := state()
	if not bool(saved.opened): return
	var elapsed := minf(MOTION, float(saved.elapsed) + delta)
	if not is_equal_approx(elapsed, float(saved.elapsed)):
		saved.elapsed = elapsed
		host.quest_state[KEY] = saved
	apply_parts()

func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if use(): get_viewport().set_input_as_handled()
