extends Node3D
## STORY-082 (HINTBOOK 5414-5427). Human breaks the bars, Lizard enters the gutter,
## Human shoots three slots. Movable 77 is the Sewer door at the region-738 crawl.
## Its only record is kind 6 caller 15, group 7898: ten opcode 196 commands that
## raise corridor regions 40 and 61-69 from -40 to -20. That group has no opcode 1,
## so the door does not travel here. The switch groups travel it.
## Movables 74, 75, and 76 are the slotted switches. Each has kind 6 caller 15
## and caller 16. What 15 means versus 16 is UNKNOWN. Left click sends 15 and
## right click sends 16 so both groups can run. That pairing is an adapter.
## The click is the viewport button. Headless has no window, so capture does not
## stick, and the host still takes that button. A real window still requires capture.
## Caller 15 adds 1 to local 0. On the shot that already sees local 0 equal 2,
## the flood group sets the channel floors to -45 and opcode 1 writes movable 77
## travel from its angle byte. Caller 16 subtracts 1. On the shot that already
## sees local 0 equal 1, the drain group restores those floors and travel 0.
## The hinge body of each switch carries the hit receiver. A Human with the blue
## bow or the dark bow equipped can shoot it. Standing at a slot does not mark it.
## No gutter volume is stored. Region 738 is the crawl (floor -40, x -349..-339,
## z -1713..-1489). The G prompt at its south lip copies the L14 passage.
## No opcode tests Human or Lizard. Form 0 is Human. Form 2 is Lizard.
## BARS and GUTTER stay -1. The leaf rise after the strike is presentation.
## The region-edge rule makes the mouth's source walls solid. Region 38's lintel
## covers the crawl at z -1713 from y -15 up, and region 40's wall runs east from
## x -339. Either one can be the first thing the camera ray meets. The bars host
## still owns that hit when it lies in the hit volume. The struck binder does not:
## this movable has no kind-9 record, and L19 skips it so L9's movable 77 stays armed.
const Forms = preload("res://scripts/lol2/player_form_rules.gd")
const KEY := "l19_sewer_forms"
const BARS := -1
const GUTTER := -1
const SWITCHES := [74, 75, 76]
const RECORD_REGIONS := [36, 34, 32]
const NAV_REGION := 30
const DOOR := 77
const GROUP := 7898
const BLUE_BOW := "act2:L12_CM:blue_bow"
const DARK_BOW := "act2:L16_CA:item24"
const AT_74 := Vector3(-323, 30, -2124)
const AT_75 := Vector3(-304, 30, -2124)
const AT_76 := Vector3(-281, 30, -2124)
const AIM_74 := Vector3(-323.5, 43.5, -2116.0)
const AIM_75 := Vector3(-304.5, 43.5, -2116.0)
const AIM_76 := Vector3(-281.5, 43.5, -2116.0)
const DOOR_AT := Vector3(-344, -40, -1621)
const MOUTH := Vector3(-339.0, -8.0, -1713.0)
const MOUTH_REACH := 80.0
const REACH := 12.0
const STRIKE_REACH := 96.0
const BAR_HIT_AT := Vector3(-344.0, -20.0, -1667.0)
const BAR_HIT_SIZE := Vector3(16.0, 48.0, 130.0)
## The east jamb ray from the corridor stand crosses 4 units outside the box.
const BAR_HIT_MARGIN := 8.0
var host: Node3D
var hint: Label
var stage: Label
var bars: MeshInstance3D
var hit_body: StaticBody3D

class BarHit:
	extends RefCounted
	var owner: Node
	func _init(n: Node) -> void:
		owner = n
	func receive_hit() -> bool:
		return owner.strike_bars()

## The receiver sits on the hinge body the binder already built for the switch.
class SwitchHit:
	extends RefCounted
	var owner: Node
	var slot: int
	func _init(n: Node, id: int) -> void:
		owner = n
		slot = id
	func receive_shot(caller: int) -> bool:
		return owner.shoot_switch(slot, caller)

static func initial() -> Dictionary:
	return {"version": 1, "lizard_at_wall": false, "switches": []}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary: return "Invalid sewer form state."
	var counted: bool = s.has("counter")
	if s.size() != (4 if counted else 3): return "Invalid sewer form state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid sewer form state."
	if not (s.get("lizard_at_wall") is bool): return "Invalid sewer form state."
	if counted:
		var counter: Variant = s.get("counter")
		if not (counter is int or counter is float) or not is_finite(float(counter)) or float(counter) != floorf(float(counter)) or int(counter) < 0 or int(counter) > 255:
			return "Invalid sewer form state."
	var listed: Variant = s.get("switches")
	if not listed is Array: return "Invalid sewer form state."
	var seen: Dictionary = {}
	for id in listed:
		if not (id is int or id is float) or seen.has(int(id)) or not int(id) in SWITCHES: return "Invalid sewer form state."
		seen[int(id)] = true
	return ""

static func bars_breakable(form: int) -> bool:
	return form == 0

static func gutter_enterable(form: int) -> bool:
	return form == 2

static func moves_door() -> bool:
	return false

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l19_sewer_forms.gd").new()
	n.host = map
	n.name = "L19SewerForms"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, initial())
	if not raw is Dictionary: return initial()
	var switches: Array = []
	var listed: Variant = raw.get("switches", [])
	if listed is Array:
		for id in listed:
			switches.append(int(id))
	var out: Dictionary = {"version": int(raw.get("version", 1)), "lizard_at_wall": bool(raw.get("lizard_at_wall", false)), "switches": switches}
	if raw.has("counter"):
		out["counter"] = int(raw.get("counter")) & 255
	return out

## A bow equipped as the weapon or held in the hand from the pack ('Hold in hand'): Grok 2026-11-16 picked 'Hold in hand'
## for the Dark Bow and the switches stayed empty.
func bow_equipped() -> bool:
	return str(host.get("equipped_item")) in [BLUE_BOW, DARK_BOW] or str(host.get("hand_item")) in [BLUE_BOW, DARK_BOW]

## The area save does not store native locals. The optional counter key is local 0.
func _sync_counter() -> void:
	if host.progression == null or host.progression.native == null:
		return
	var native: Object = host.progression.native
	if native.locals.has(0):
		return
	var raw: Variant = host.quest_state.get(KEY, {})
	if raw is Dictionary and raw.has("counter"):
		native.set_local(0, int(raw.get("counter")) & 255)

func flat_to(point: Vector3) -> float:
	var p: Vector3 = host.player.global_position
	return Vector2(p.x - point.x, p.z - point.z).length()

func near_switch() -> int:
	if flat_to(AT_74) < REACH: return 74
	if flat_to(AT_75) < REACH: return 75
	if flat_to(AT_76) < REACH: return 76
	return -1

func at_mouth() -> bool:
	return not host.flying and host.starting_magic.world_active() and flat_to(MOUTH) < MOUTH_REACH

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 468)
	canvas.add_child(hint)
	stage = Label.new()
	stage.name = "Stage"
	stage.position = Vector2(24, 436)
	canvas.add_child(stage)
	bars = _box("BarLeaf", DOOR_AT, Color(0.4, 0.4, 0.45))
	hit_body = StaticBody3D.new()
	hit_body.name = "BarHit"
	hit_body.collision_layer = 4
	hit_body.collision_mask = 0
	hit_body.position = BAR_HIT_AT
	hit_body.set_meta("hive_hit_receiver", BarHit.new(self))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BAR_HIT_SIZE
	shape.shape = box
	hit_body.add_child(shape)
	add_child(hit_body)
	_arm_switches()

func _arm_switches() -> void:
	if host.progression == null:
		return
	for id in SWITCHES:
		if not host.progression.mover_bodies.has(int(id)):
			continue
		var body: CollisionObject3D = host.progression.mover_bodies[int(id)]
		body.set_meta("bow_hit_receiver", SwitchHit.new(self, int(id)))

func _box(node_name: String, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = node_name
	var box := BoxMesh.new()
	box.size = Vector3(10, 16, 10)
	mesh_node.mesh = box
	mesh_node.position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mesh_node.material_override = mat
	add_child(mesh_node)
	return mesh_node

func strike_bars() -> bool:
	if host.flying or not host.starting_magic.world_active():
		return false
	if not bars_breakable(int(host.player_form)):
		return false
	var results: Array = host.progression.fire("movable:77", 6, {"caller_byte": 15})
	var ran := false
	for row in results:
		if int(row.group) == GROUP and str(row.status) == "ran":
			ran = true
	if ran:
		bars.position.y = DOOR_AT.y + 4.0
	return ran

func shoot_switch(id: int, caller: int) -> bool:
	if host.flying or not host.starting_magic.world_active():
		return false
	if int(host.player_form) != 0 or not Forms.can_use_weapon(int(host.player_form)):
		return false
	if not bow_equipped():
		return false
	if not id in SWITCHES or (caller != 15 and caller != 16):
		return false
	_sync_counter()
	var results: Array = host.progression.fire("movable:%d" % id, 6, {"caller_byte": caller})
	var ran := false
	for row in results:
		if str(row.status) == "ran":
			ran = true
	if not ran:
		return false
	var s: Dictionary = state()
	var native: Object = host.progression.native
	if native.locals.has(0):
		s["counter"] = int(native.locals[0]) & 255
	if caller == 15:
		var ids: Array = s.switches
		if not id in ids:
			ids.append(id)
			s.switches = ids
	host.quest_state[KEY] = s
	return true

func shot_from_camera(caller: int) -> bool:
	if host.flying or not host.starting_magic.world_active() or host.camera == null:
		return false
	var origin: Vector3 = host.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin - host.camera.global_basis.z * STRIKE_REACH, 7, [host.player.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("bow_hit_receiver"):
		return false
	return bool(hit.collider.get_meta("bow_hit_receiver").receive_shot(caller))

func _in_bars_volume(point: Vector3) -> bool:
	var half := BAR_HIT_SIZE * 0.5 + Vector3(BAR_HIT_MARGIN, BAR_HIT_MARGIN, BAR_HIT_MARGIN)
	var delta := point - BAR_HIT_AT
	return absf(delta.x) <= half.x and absf(delta.y) <= half.y and absf(delta.z) <= half.z

## Mask 7 matches the hive strike. A region-edge source wall at the mouth can be closer than the hit body.
## The bars host wins when that point is still in the hit volume. A closer layer-2 body keeps the click.
func strike_from_camera() -> bool:
	if host.flying or not host.starting_magic.world_active() or host.camera == null:
		return false
	var origin: Vector3 = host.camera.global_position
	var end: Vector3 = origin - host.camera.global_basis.z * STRIKE_REACH
	var exclude: Array[RID] = [host.player.get_rid()]
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 7, exclude))
	if not hit.is_empty() and hit.collider.has_meta("hive_hit_receiver"):
		return bool(hit.collider.get_meta("hive_hit_receiver").receive_hit())
	var bars: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 4, exclude))
	if bars.is_empty() or not bars.collider.has_meta("hive_hit_receiver"):
		return false
	if not hit.is_empty():
		var body: CollisionObject3D = hit.collider
		var blocked_at: Vector3 = hit.position
		var bars_at: Vector3 = bars.position
		if (int(body.collision_layer) & 2) != 0 and origin.distance_to(blocked_at) + 0.5 < origin.distance_to(bars_at):
			return false
		if not _in_bars_volume(blocked_at):
			return false
	return bool(bars.collider.get_meta("hive_hit_receiver").receive_hit())

func choose_form() -> bool:
	if not at_mouth() or host.curse.state.phase in [1, 3]:
		return false
	var form: int = int(host.player_form)
	if form == 0:
		if not host.curse.request_timed_form(2, 60.0):
			return false
		var s: Dictionary = state()
		s.lizard_at_wall = true
		host.quest_state[KEY] = s
		return true
	if form == 2:
		return host.curse.request_human()
	return false

func _hint_slot() -> int:
	if flat_to(AT_74) < STRIKE_REACH: return 74
	if flat_to(AT_75) < STRIKE_REACH: return 75
	if flat_to(AT_76) < STRIKE_REACH: return 76
	return -1

func _process(_delta: float) -> void:
	_sync_counter()
	hint.text = ""
	stage.text = ""
	if host.flying or not host.starting_magic.world_active():
		return
	if at_mouth():
		var form: int = int(host.player_form)
		if form == 0:
			stage.text = "G — Change to Lizard for the gutter"
		elif form == 2:
			stage.text = "G — Return to Human"
	if int(host.player_form) == 0 and flat_to(DOOR_AT) < 160.0:
		hint.text = "Left click — Break the bars"
	var slot: int = _hint_slot()
	if slot < 0:
		return
	var form_at_slot: int = int(host.player_form)
	if form_at_slot == 2:
		hint.text = "Back to the Human; the three slotted switches lie beyond."
		return
	if form_at_slot != 0 or not Forms.can_use_weapon(form_at_slot) or not bow_equipped():
		hint.text = "The three slotted switches want the Human and a bow."
		return
	hint.text = "Shoot the slotted switch."

## Headless has no window, so a captured mouse cannot stick. A real window still requires it.
func _player_click() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _player_click():
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Caller 15 on the left button and caller 16 on the right button are an adapter.
			# The native split between those two caller bytes is UNKNOWN.
			if bow_equipped() and shot_from_camera(15):
				get_viewport().set_input_as_handled()
			elif strike_from_camera():
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and bow_equipped() and shot_from_camera(16):
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G and choose_form():
		get_viewport().set_input_as_handled()
