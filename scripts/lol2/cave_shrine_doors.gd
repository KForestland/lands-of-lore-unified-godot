extends Node3D
## Shrine doorway blocks = static assemblies / controls 0 and 1 (tools/prepare_cave_shrine_doors.py, owner report
## 2026-10-20 18:53). Two solid template43 blocks close the corridor at native y 10758 (gaps 7/20/10 units). Each
## control's only record is kind10 contact with actor38 (walker AE7D8 case6): when the colonnade guard touches either
## block, that control's group runs two op18 and both blocks slide sideways into the corridor niches.
## Modern adapter (docs/DEVIATIONS.md): the player touching a block runs the same group. The longplay (9:05-9:08,
## 4 fps) shows the blocks parting as the human player presses into the gap with no guard in view, and the CRASH
## walkthrough says "move the two stone blocks, then the guard at the other end"; the native trigger for that is not
## yet identified (the only record names actor38). The ordinary middle route walks through here, before region1941
## can spawn guard38, so a guard-only door would block Act 1. Drawn by the static-assembly renderer (set_offset).
## Saved as "cave_shrine_doors".
const SOURCE := "res://scripts/lol2/cave_shrine_doors_source.json"
const CONTROLS := [0, 1]
## Adapter: op18 flags 0x12 / byte15 10 travel is not replayed; linear slide time.
const SLIDE_SECONDS := 1.5
## Adapter: the guard capsule (radius 15) touching a block box, with 2 units of slack for move_and_slide's margin.
const CONTACT_REACH := 17.0

var host: Node3D
var src: Dictionary = {}
## 0 closed, 1 sliding, 2 open.
var state := 0
var group := 0
var clock := 0.0
var boxes: Dictionary = {}    # control -> AABB at the placement (host coordinates)
var bodies: Dictionary = {}   # control -> StaticBody3D

static func source() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SOURCE)) if FileAccess.file_exists(SOURCE) else null
	return data if data is Dictionary else {}

static func assets_ready() -> bool:
	return not source().is_empty()

static func initial() -> Dictionary:
	return {"version":1, "state":0, "group":0, "clock":0.0}

static func validate(saved: Variant, source_data: Dictionary) -> String:
	if not saved is Dictionary or saved.size() != 4 or not saved.has_all(["version", "state", "group", "clock"]): return "Invalid shrine doors state."
	for key in ["version", "state", "group"]:
		if not (saved[key] is int or saved[key] is float) or float(saved[key]) != floorf(float(saved[key])): return "Invalid shrine doors state."
	if not (saved.clock is int or saved.clock is float) or not is_finite(float(saved.clock)): return "Invalid shrine doors state."
	var s := int(saved.state)
	if int(saved.version) != 1 or not s in [0, 1, 2]: return "Invalid shrine doors state."
	if (s == 0) != (int(saved.group) == 0) or (s != 0 and not source_data.get("poses", {}).has(str(int(saved.group)))): return "Invalid shrine doors state."
	if float(saved.clock) < 0 or float(saved.clock) >= SLIDE_SECONDS or (s != 1 and float(saved.clock) != 0.0): return "Invalid shrine doors state."
	return ""

func setup(owner_host: Node3D) -> String:
	host = owner_host
	name = "CaveShrineDoors"
	src = source()
	if src.is_empty(): return "Shrine doors source missing."
	var assemblies = host.get("static_assemblies")
	if assemblies == null or not is_instance_valid(assemblies): return "Shrine doors need the static-assembly renderer."
	var offset: Vector3 = host.native_translation
	for control in CONTROLS:
		var low := Vector3.INF
		var high := -Vector3.INF
		for face in assemblies.data.faces:
			if int(face.assembly) != control or not face.initial: continue
			for p in face.points:
				var v := Vector3(p[0], p[1], p[2]) + offset
				low = low.min(v)
				high = high.max(v)
		if low == Vector3.INF: return "Shrine block %d has no faces." % control
		boxes[control] = AABB(low, high - low)
		var body := StaticBody3D.new()
		body.name = "Block%d" % control
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = high - low
		shape.shape = box
		shape.position = (low + high) / 2.0
		body.add_child(shape)
		add_child(body)
		bodies[control] = body
	return restore(null)

func checkpoint() -> Dictionary:
	return {"version":1, "state":state, "group":group, "clock":clock}

func restore(saved: Variant) -> String:
	var proposed: Variant = saved if saved != null else initial()
	var error := validate(proposed, src)
	if not error.is_empty(): return error
	state = int(proposed.state)
	group = int(proposed.group)
	clock = float(proposed.clock)
	present()
	return ""

## Offset of `control` from its placement at slide fraction t (native y -> Godot -z).
func offset(control: int, t: float) -> Vector3:
	if group == 0: return Vector3.ZERO
	var pose: Dictionary = src.poses[str(group)][str(control)]
	var place: Dictionary = src.placements[str(control)]
	return Vector3(float(pose.x) - float(place.x), 0.0, -(float(pose.y) - float(place.y))) * clampf(t, 0.0, 1.0)

func fraction() -> float:
	return 1.0 if state == 2 else (clock / SLIDE_SECONDS if state == 1 else 0.0)

func present() -> void:
	var t := fraction()
	for control in CONTROLS:
		var shift := offset(control, t)
		bodies[control].position = shift
		host.static_assemblies.set_offset(control, shift)

func _guard() -> Dictionary:
	var population = host.get("guard_population")
	if population == null or not is_instance_valid(population): return {}
	var id := str(int(src.guard))
	if not population.state.actors.has(id) or not population.bodies.has(id): return {}
	var actor: Dictionary = population.state.actors[id]
	if not bool(actor.present) or int(actor.health) <= 0: return {}
	return {"actor":actor, "body":population.bodies[id]}

## The control whose block the guard touches (horizontal distance from the capsule axis to the box), or -1.
func touched(position: Vector3, reach := CONTACT_REACH) -> int:
	for control in CONTROLS:
		var box: AABB = boxes[control]
		if position.y > box.end.y or position.y + 46.0 < box.position.y: continue
		var dx := maxf(maxf(box.position.x - position.x, 0.0), position.x - box.end.x)
		var dz := maxf(maxf(box.position.z - position.z, 0.0), position.z - box.end.z)
		if Vector2(dx, dz).length() <= reach: return control
	return -1

## Kind10 contact (record byte4 6: the other object is actor38): run the touched control's group (two op18).
func contact(control: int) -> bool:
	if state != 0 or not control in CONTROLS: return false
	group = int(src.controls[str(control)].group)
	state = 1
	clock = 0.0
	present()
	return true

func advance(delta: float) -> void:
	if state == 0:
		var g := _guard()
		if not g.is_empty():
			var control := touched(g.body.global_position)
			if control >= 0: contact(control)
		if state == 0 and is_instance_valid(host.get("player")):
			# Player body origin is 32 above the feet (player_form_body FOOT_OFFSET); reach = form radius + 2.
			var feet: Vector3 = host.player.global_position - Vector3(0, 32, 0)
			var form := int(host.get("player_form")) if host.get("player_form") != null else 0
			var control := touched(feet, preload("res://scripts/lol2/player_form_body.gd").RADII[clampi(form, 0, 2)] + 2.0)
			if control >= 0: contact(control)
		return
	if state != 1 or not is_finite(delta) or delta <= 0: return
	clock += delta
	if clock >= SLIDE_SECONDS:
		state = 2
		clock = 0.0
	present()

func _world_active() -> bool:
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic): return host.starting_magic.world_active()
	return not host.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_instance_valid(host) or not host.get("walkthrough_ready") or not _world_active(): return
	advance(delta)
