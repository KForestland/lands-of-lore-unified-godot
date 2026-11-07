extends Node3D
## STORY-073, STORY-074, and STORY-075 (HINTBOOK 4941-4954 and 5114-5200; I06, I07).
## Controls 173-176 are the ivory pedestals. E with one of the five known chip ids in hand
## sets that pedestal. Four chips record the foyer. Prop 604 stays whole. Doors 89-91 stay shut.
## A fourth L16 ivory placement was not found. The force field, the gargoyle grant, the ice
## fountain, and the ceiling drop stay off this module.
const KEY := "l16_sw_chips"
const PEDESTALS := [
	Vector3(-10089, 36, 12935),
	Vector3(-9949, 36, 12936),
	Vector3(-9645, 36, 12936),
	Vector3(-9505, 36, 12936),
]
const CHIP_IDS := [
	"act2:L16_CA:item12",
	"act2:L16_CA:item22",
	"act2:L16_CA:item23",
	"museum:item17:Ivory_Chip",
	"museum:item18:Ivory_Chip",
]
const PYRAMID := 604
const DOORS := [89, 90, 91]
var host: Node3D
var hint: Label
var chips: Array = []

static func initial() -> Dictionary:
	return {"version": 1, "placed": []}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or s.size() != 2 or not s.get("placed") is Array: return "Invalid ivory pedestal state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1: return "Invalid ivory pedestal state."
	var seen: Dictionary = {}
	for r in s.placed:
		if not (r is int or r is float) or int(r) < 0 or int(r) > 3 or seen.has(int(r)): return "Invalid ivory pedestal."
		seen[int(r)] = true
	return ""

static func apply_place(s: Dictionary, index: int, chip: String) -> Dictionary:
	if chip not in CHIP_IDS or index < 0 or index > 3 or s.placed.size() >= 4: return s
	for r in s.placed:
		if int(r) == index: return s
	var nxt: Dictionary = s.duplicate(true)
	nxt.placed.append(index)
	return nxt

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l16_sw_chips.gd").new()
	n.host = map
	n.name = "L16SwChips"
	map.add_child(n)
	return n

func state() -> Dictionary:
	return host.quest_state.get(KEY, initial())

func held_chip() -> String:
	var hand := str(host.hand_item)
	if hand in CHIP_IDS: return hand
	return ""

func _ready() -> void:
	for index in PEDESTALS.size():
		var chip := MeshInstance3D.new()
		chip.name = "IvoryOnPedestal%d" % index
		var box := BoxMesh.new()
		box.size = Vector3(6, 4, 6)
		chip.mesh = box
		chip.position = PEDESTALS[index]
		var ivory := StandardMaterial3D.new()
		ivory.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ivory.albedo_color = Color(0.93, 0.9, 0.78)
		chip.material_override = ivory
		add_child(chip)
		chips.append(chip)
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 420)
	canvas.add_child(hint)
	restore()

func _indexes() -> Dictionary:
	var out: Dictionary = {}
	for r in state().placed: out[int(r)] = true
	return out

func restore() -> void:
	var have := _indexes()
	for index in chips.size():
		chips[index].visible = have.has(index)

func aimed_index() -> int:
	for index in PEDESTALS.size():
		if aimed(PEDESTALS[index], 150.0): return index
	return -1

func aimed(point: Vector3, reach: float) -> bool:
	if not host.starting_magic.world_active() or host.flying: return false
	var d: Vector3 = point - host.camera.global_position
	if d.length() < 0.01 or d.length() >= reach: return false
	return (-host.camera.global_basis.z).dot(d.normalized()) > 0.9

func offer(index: int) -> Dictionary:
	var chip := held_chip()
	if chip.is_empty(): return {"ok": false, "reason": "The pedestal takes an ivory chip."}
	var nxt: Dictionary = apply_place(state(), index, chip)
	if nxt.placed == state().placed: return {"ok": false, "reason": "A chip already sits here."}
	host.carried_collected.erase(chip)
	if str(host.hand_item) == chip: host.hand_item = ""
	host.quest_state[KEY] = nxt
	restore()
	if nxt.placed.size() >= 4: return {"ok": true, "reason": "Four chips sit on the pedestals. The tower door stays shut."}
	return {"ok": true, "reason": "The ivory chip sits on the pedestal."}

func _process(_delta: float) -> void:
	hint.text = ""
	var index := aimed_index()
	if index < 0: return
	if held_chip().is_empty(): hint.text = "The pedestal takes an ivory chip."
	else: hint.text = "E — Set an ivory chip on the pedestal"
	restore()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	var index := aimed_index()
	if index < 0: return
	host.save_feedback(str(offer(index).reason))
	get_viewport().set_input_as_handled()
