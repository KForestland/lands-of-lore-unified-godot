extends Node
## Museum control 92, the long beam in front of the dragon door (owner r17 16-37-36).
## Group 7596 opcode 18 names control 92 at (3114, 824), height word 0, flags 0x0092, byte 15 0x28.
## Bit 0x0004 is clear, so the words are not an instant relocation (the pending reader is unentered).
## Bit 0x0100 is clear, so the height word is not applied and the beam stays at placement height 35.
## The slide time is the cave-shrine adapter (SLIDE_SECONDS). Byte 15 is not replayed as a speed.
## Kind 6 value 6, group 7678, sets movable 82 to state 1. That is the hosted dragon-door open.
const CONTROL := 92
const REACH := 96.0
const AIM := 0.97
## Native (3114 - 3049, 824 - 826) with Godot z = -native y. Height stays put.
const SLIDE := Vector3(65.0, 0.0, 2.0)
const SLIDE_SECONDS := 1.5
const State = preload("res://scripts/lol2/scripted_creature_state.gd")

var host: Node3D
## 0 in place, 1 sliding, 2 seated in the slot.
var state := 0
var clock := 0.0

static func initial() -> Dictionary:
	return {"version": 1, "state": 0, "clock": 0.0}

static func validate(saved: Variant) -> String:
	if not saved is Dictionary or saved.size() != 3 or not saved.has_all(["version", "state", "clock"]): return "Invalid museum plank."
	for key in ["version", "state"]:
		var n: Variant = saved[key]
		if not (n is int or n is float) or float(n) != floorf(float(n)): return "Invalid museum plank."
	var clock_value: Variant = saved["clock"]
	if not (clock_value is int or clock_value is float) or not is_finite(float(clock_value)): return "Invalid museum plank."
	var s := int(saved["state"])
	if int(saved["version"]) != 1 or not s in [0, 1, 2]: return "Invalid museum plank."
	if float(clock_value) < 0.0 or float(clock_value) >= SLIDE_SECONDS or (s != 1 and float(clock_value) != 0.0): return "Invalid museum plank."
	return ""

func setup(owner_host: Node3D, saved: Variant) -> String:
	host = owner_host
	return restore(saved)

func checkpoint() -> Dictionary:
	return {"version": 1, "state": state, "clock": clock}

func restore(saved: Variant) -> String:
	var proposed: Variant = saved if saved != null else initial()
	var error := validate(proposed)
	if not error.is_empty(): return error
	state = int(proposed["state"])
	clock = float(proposed["clock"])
	present()
	return ""

func shift() -> Vector3:
	var t := 1.0 if state == 2 else (clock / SLIDE_SECONDS if state == 1 else 0.0)
	return SLIDE * t

func present() -> void:
	var assemblies: Variant = host.get("static_assemblies")
	if assemblies == null or not is_instance_valid(assemblies): return
	assemblies.set_offset(CONTROL, shift())

## A finished slide whose door save did not record the open. Live play opens the door from _physics_process.
func settle_door() -> void:
	if state != 2: return
	var door: Variant = host.get("dragon_door")
	if door == null or not is_instance_valid(door) or bool(door.opened): return
	door.open()
	door.progress = 1.0
	door.position.y = 80.0

func beam_bounds() -> AABB:
	var assemblies: Variant = host.get("static_assemblies")
	if assemblies == null or not is_instance_valid(assemblies): return AABB()
	var listed: Variant = assemblies.stateful_meshes.get(CONTROL, [])
	if not listed is Array: return AABB()
	var box := AABB()
	var any := false
	for mesh in listed:
		if not mesh is MeshInstance3D: continue
		var part: AABB = (mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
		box = part if not any else box.merge(part)
		any = true
	return box

func interaction_hint() -> String:
	if state != 0 or not _gates() or _center_aimed(): return ""
	if not _on_beam(): return ""
	return "E — Slide the plank in"

## Kind 4 on control 92. A held item stays in the hand: the beam is not a grant.
func press() -> bool:
	if state != 0 or not _gates(): return false
	var pop: Variant = host.get("skeleton_population")
	if pop == null or not is_instance_valid(pop): return false
	if _center_aimed():
		if not bool(pop.use_control()): return false
	elif _on_beam():
		var creature_state: Dictionary = pop.state
		var src: Dictionary = pop.src
		var touched: Array = State.use_control(creature_state, src, "92")
		if touched.is_empty() and int(creature_state.get("controls", {}).get("92", 0)) != 1: return false
		pop.sync_quests()
		if host.has_method("save_feedback"): host.save_feedback("Something stirs.")
		pop.present()
	else:
		return false
	state = 1
	clock = 0.0
	present()
	return true

func _physics_process(delta: float) -> void:
	if state != 1 or not is_instance_valid(host) or host.get_tree().paused: return
	if not is_finite(delta) or delta <= 0.0: return
	clock += delta
	var arrived := false
	if clock >= SLIDE_SECONDS:
		state = 2
		clock = 0.0
		arrived = true
	present()
	if not arrived: return
	var door: Variant = host.get("dragon_door")
	if door != null and is_instance_valid(door): door.open()

func _gates() -> bool:
	if not is_instance_valid(host) or host.get_tree().paused or host.get("flying") == true: return false
	if str(host.get("introduction_state")) != "complete" or host.get("mirror_transition_pending") == true: return false
	var hud: Variant = host.get("interface_hud")
	if hud != null and is_instance_valid(hud) and bool(hud.cursor_active): return false
	var magic: Variant = host.get("starting_magic")
	if magic == null or not is_instance_valid(magic) or not bool(magic.world_active()): return false
	return true

func _center_aimed() -> bool:
	var pop: Variant = host.get("skeleton_population")
	return pop != null and is_instance_valid(pop) and str(pop.aimed_control()) == "92"

func _on_beam() -> bool:
	var box := beam_bounds()
	if box.size == Vector3.ZERO: return false
	var camera := host.get("camera") as Camera3D
	if camera == null: return false
	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z
	var center: Vector3 = box.get_center()
	var delta: Vector3 = center - origin
	if delta.length() < 0.01 or delta.length() > REACH: return false
	if forward.dot(delta.normalized()) >= AIM and _clear(center): return true
	var hit := _hit_box(origin, forward, box)
	if not is_finite(hit.x) or origin.distance_to(hit) > REACH: return false
	return _clear(hit)

func _clear(at: Vector3) -> bool:
	var camera := host.get("camera") as Camera3D
	var player := host.get("player") as CollisionObject3D
	if camera == null or player == null: return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, at, preload("res://scripts/lol2/region_blockers.gd").RAY_MASK)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.position.distance_to(at) <= 12.0

func _hit_box(origin: Vector3, direction: Vector3, box: AABB) -> Vector3:
	var t_min := 0.0
	var t_max := REACH
	var low: Vector3 = box.position
	var high: Vector3 = box.end
	for axis_i in range(3):
		var axis: int = axis_i
		var o: float = _axis(origin, axis)
		var d: float = _axis(direction, axis)
		var b0: float = _axis(low, axis)
		var b1: float = _axis(high, axis)
		if absf(d) < 0.000001:
			if o < b0 or o > b1: return Vector3(INF, INF, INF)
		else:
			var t0: float = (b0 - o) / d
			var t1: float = (b1 - o) / d
			if t0 > t1:
				var swap: float = t0
				t0 = t1
				t1 = swap
			t_min = maxf(t_min, t0)
			t_max = minf(t_max, t1)
			if t_min > t_max: return Vector3(INF, INF, INF)
	return origin + direction * t_min

func _axis(v: Vector3, axis: int) -> float:
	match axis:
		0: return v.x
		1: return v.y
		_: return v.z
