extends Node3D
## STORY-070 NE greenhouse (Prima p.148-149, hintbook 4866-4900): put a silverleaf into the glass pyramid, use the
## hourglass; a plant bursts from the pyramid and a fireball drifts to the tower in the middle of the round room; when it
## hits the doors they open. Native ids (source_ids_066_075.md STORY-070): Silverleaf plate control 75 (kind 4 group 42062:
## pyramid prop 605 +0x25 = 1, selector 4), Silverleaf Pyramid prop 605, Hourglass prop 627 (kind 4 group 40684: sound,
## enqueue 605, light the 14 altars 502-515), Ball O Smoke prop 602 (opcode 18 path to native (2290,2951); kind 10 group
## 37776: experience, opcode 1 FireWall Doors movables 92/93/94 = 100, remove itself).
## Adapters (DEVIATIONS): E on the plate with a carried Silverleaf consumes one; E on the hourglass after that starts the
## fireball; the pyramid's growth predicates (left type 4) and the watering valves (yellow figure, optional per the book)
## are not hosted; the fireball drifts at 120 units/s; on arrival the native kind-10 group runs and the three doors are
## posed open even if the host refuses part of that group.
const KEY := "l16_greenhouse"
const PLATE := Vector3(2287, 34, -593)
const HOURGLASS := Vector3(2293, 75, -1070)
const BALL_START := Vector3(2289, 18, -648)
const BALL_END := Vector3(2290, 18, -2951)
const BALL_RECORD := 602
const DOORS := [92, 93, 94]
const SPEED := 120.0
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
var host: Node3D
var hint: Label

static func initial() -> Dictionary: return {"version":1,"silverleaf":"","fireball":0.0,"opened":false}
static func validate(s: Variant, quests: Dictionary) -> String:
	if not s is Dictionary or s.size() != 4 or s.get("version") != 1 or not s.get("silverleaf") is String or not s.get("opened") is bool: return "Invalid greenhouse state."
	var f = s.get("fireball")
	if not (f is int or f is float) or not is_finite(float(f)) or float(f) < 0 or float(f) > 1: return "Invalid greenhouse fireball."
	if float(f) > 0 and s.silverleaf.is_empty(): return "Greenhouse fireball without a silverleaf."
	if s.opened and float(f) < 1: return "Greenhouse doors opened before the fireball arrived."
	return ""
static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l16_greenhouse.gd").new(); n.host = map; n.name = "L16Greenhouse"; map.add_child(n); return n

func state() -> Dictionary: return host.quest_state.get(KEY, initial())

func _ready() -> void:
	var canvas := CanvasLayer.new(); canvas.layer = 34; add_child(canvas); hint = Label.new(); hint.position = Vector2(24,420); canvas.add_child(hint)
	restore()

func _ball_at(p: Vector3, shown: bool) -> void:
	var row: Variant = host.prop_placements.get(BALL_RECORD)
	if not row is Array: return
	(row[0] as MultiMesh).set_instance_transform(int(row[1]), Transform3D(Basis() if shown else Basis().scaled(Vector3.ZERO), p))

func restore() -> void:
	var s := state()
	var f := float(s.fireball)
	_ball_at(BALL_START.lerp(BALL_END, f), not s.opened)
	if s.opened: _open_doors()

func _open_doors() -> void:
	var pr = host.progression
	for id in DOORS:
		if pr.hinges.has(id) and int(pr.travel.get(id, 0)) != 100:
			pr.travel[id] = 100; pr._pose(id)

func aimed(point: Vector3, reach: float) -> bool:
	if not host.starting_magic.world_active() or host.flying: return false
	var d: Vector3 = point - host.camera.global_position
	return d.length() < reach and d.length() > 0.01 and (-host.camera.global_basis.z).dot(d.normalized()) > 0.9

func carried_silverleaf() -> String:
	if Items.definition(str(host.hand_item)) == 117: return str(host.hand_item)
	for id in host.carried_collected:
		if Items.definition(str(id)) == 117: return str(id)
	return ""

func place_silverleaf() -> Dictionary:
	if not state().silverleaf.is_empty(): return {"ok":false,"reason":"A silverleaf already rests in the glass pyramid."}
	var leaf := carried_silverleaf()
	if leaf.is_empty(): return {"ok":false,"reason":"The glass pyramid needs a silverleaf."}
	host.carried_collected.erase(leaf)
	if host.hand_item == leaf: host.hand_item = ""
	Items.sync(host)
	var s := state().duplicate(true); s.silverleaf = leaf; host.quest_state[KEY] = s
	host.progression.fire("control:75", 4, {"arg_c":3})
	return {"ok":true,"reason":"You set the silverleaf into the glass pyramid."}

func use_hourglass() -> Dictionary:
	host.progression.fire("prop:627", 4, {})
	var s := state()
	if s.silverleaf.is_empty() or float(s.fireball) > 0: return {"ok":true,"reason":"The hourglass chimes and ticks for a while."}
	s = s.duplicate(true); s.fireball = 0.001; host.quest_state[KEY] = s
	return {"ok":true,"reason":"A plant bursts from the glass pyramid. A fireball drifts toward the tower."}

func _physics_process(delta: float) -> void:
	var s := state()
	if s.opened or float(s.fireball) <= 0 or not host.starting_magic.world_active(): return
	var total := BALL_START.distance_to(BALL_END)
	var f := minf(1.0, float(s.fireball) + SPEED * delta / total)
	s = s.duplicate(true); s.fireball = f
	if f >= 1.0:
		s.opened = true; host.quest_state[KEY] = s
		host.progression.fire("prop:%d" % BALL_RECORD, 10, {})
		host.save_feedback("The fireball strikes the tower doors and they open.")
	else:
		host.quest_state[KEY] = s
	restore()

func _process(_delta: float) -> void:
	hint.text = ""
	if aimed(PLATE, 150.0) and state().silverleaf.is_empty(): hint.text = "E — Put a silverleaf into the glass pyramid"
	elif aimed(HOURGLASS, 130.0): hint.text = "E — Turn the hourglass"

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	var r: Dictionary
	if aimed(PLATE, 150.0) and state().silverleaf.is_empty(): r = place_silverleaf()
	elif aimed(HOURGLASS, 130.0): r = use_hourglass()
	else: return
	host.save_feedback(r.reason); get_viewport().set_input_as_handled()
