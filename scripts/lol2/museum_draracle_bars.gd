extends Node3D
## Draracle-wing bars (docs/museum-draracle-bars.md). Region1174 grounded entry while local17 == 0 (source g1364):
## bars 71-74 rise to 100 percent, local17 = 1 and gate77 closes. Bar travel is the native percent/travel arithmetic
## in cave_guard_movement_state.gd; geometry and collision come from cave_guard_movement.gd with this source.
## Control79 empty-hand use at Draracle local19 2 (g6976): sound394, local19 3; when it ends (g6998) sound312.
## Saved in the Museum checkpoint as "museum_draracle_bars" {"version", "local17", "movement"}.
const SOURCE := "res://scripts/lol2/museum_draracle_bars_source.json"
const Movement = preload("res://scripts/lol2/cave_guard_movement.gd")
const MovementState = preload("res://scripts/lol2/cave_guard_movement_state.gd")
## Adapter: control79 has no visual; E aims at its placement this far above the floor.
const CONTROL_AIM_HEIGHT := 40.0

var host: Node3D
var src: Dictionary = {}
var movement: Node3D
var local17 := 0
var inside := false
var tick_fraction := 0.0
var voice: AudioStreamPlayer3D
var voice_clip := 0

static func source() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	return data if data is Dictionary else {}

static func assets_ready() -> bool:
	var data := source()
	if data.is_empty(): return false
	for file in data.materials:
		if FileAccess.get_sha256(file) != str(data.materials[file]): return false
	for id in data.audio:
		if FileAccess.get_sha256(data.audio[id].path) != str(data.audio[id].wav_sha256): return false
	return true

static func movement_source(data: Dictionary) -> Dictionary:
	return {"movables": data.movables, "materials": data.materials}

static func initial(data: Dictionary) -> Dictionary:
	return {"version":1, "local17":0, "movement":MovementState.initial(movement_source(data))}

static func validate(state: Variant, data: Dictionary) -> String:
	if not state is Dictionary or state.size() != 3 or not state.has_all(["version", "local17", "movement"]): return "Invalid Draracle bars state."
	if not (state.version is int or state.version is float) or int(state.version) != 1 or float(state.version) != 1.0: return "Invalid Draracle bars state."
	if not (state.local17 is int or state.local17 is float) or float(state.local17) not in [0.0, 1.0]: return "Invalid Draracle bars state."
	var error := MovementState.validate(state.movement, movement_source(data))
	if not error.is_empty(): return error
	# The bars only move through g1364, which also sets local17.
	if int(state.local17) == 0:
		for id in state.movement.objects:
			if int(state.movement.objects[id].target) != 0 or int(state.movement.objects[id].current) != 0: return "Draracle bars moved before region1174."
	return ""

func setup(owner_host: Node3D, saved: Variant) -> String:
	host = owner_host
	src = source()
	if src.is_empty(): return "Draracle bars source missing."
	movement = Movement.new()
	movement.src = movement_source(src)
	add_child(movement)
	var proposed: Variant = saved if saved != null else initial(src)
	if not validate(proposed, src).is_empty(): proposed = initial(src)
	var error: String = movement.setup(Vector3.ZERO, proposed.movement)
	if not error.is_empty(): return error
	local17 = int(proposed.local17)
	voice = AudioStreamPlayer3D.new()
	voice.position = control_point()
	voice.finished.connect(_voice_finished)
	add_child(voice)
	return ""

func checkpoint() -> Dictionary:
	return {"version":1, "local17":local17, "movement":MovementState.canonical(movement.checkpoint())}

func restore(saved: Variant) -> String:
	var proposed: Variant = saved if saved != null else initial(src)
	var error := validate(proposed, src)
	if not error.is_empty(): return error
	error = movement.restore(proposed.movement)
	if not error.is_empty(): return error
	local17 = int(proposed.local17)
	tick_fraction = 0.0
	voice.stop(); voice_clip = 0
	return ""

## Grounded inside region1174 (floor 0, the same foot tolerance as region1220).
func region_inside(point: Vector3, foot: float, grounded: bool) -> bool:
	if not grounded or foot < float(src.floor) - 1 or foot > float(src.floor) + 3: return false
	var polygon := PackedVector2Array()
	for vertex in src.polygon: polygon.append(Vector2(vertex[0], vertex[1]))
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), polygon)

## Recompute without firing (arrival, load): standing inside is not a new entry.
func sync_inside(point: Vector3, foot: float, grounded: bool) -> void:
	inside = region_inside(point, foot, grounded)

func step(delta: float, point: Vector3, foot: float, grounded: bool) -> void:
	var now := region_inside(point, foot, grounded)
	if now and not inside and local17 == 0: enter()
	inside = now
	if not is_finite(delta) or delta <= 0: return
	tick_fraction += delta * 60.0
	while tick_fraction >= 1.0:
		tick_fraction -= 1.0
		movement.advance(65536)

## Source g1364, hosted commands in order: op1 71-74 -> 100, op198 local17 = 1, op1 77 -> 0.
func enter() -> void:
	for id in src.bars.ids: movement.command(int(id), int(src.bars.percent))
	local17 = 1
	if is_instance_valid(host.museum_gate): host.museum_gate.close()

func bars_raised() -> bool:
	for id in src.bars.ids:
		if MovementState.vertical_offset(movement.state, movement.src, int(id)) < float(src.movables[0].motion.travel): return false
	return true

func control_point() -> Vector3:
	var p: Array = src.control.position
	return Vector3(float(p[0]), float(p[1]) + CONTROL_AIM_HEIGHT, float(p[2]))

## Control79 kind4 mode0 (empty hand) under predicate55 local19 == 2: g6976 op20 sound394, op198 local19 = 3.
func use_control() -> bool:
	if host.draracle_local19 != int(src.control.use_local19): return false
	if str(host.hand_item) != "" or not host.can_reach_item(control_point()): return false
	host.draracle_local19 = int(src.control.next_local19)
	play(int(src.control.first_sound))
	return true

func play(id: int) -> void:
	var clip: AudioStream = AudioStreamWAV.load_from_file(src.audio[str(id)].path)
	if clip == null: return
	voice_clip = id
	voice.stream = clip
	voice.play()

## g6998 (event8 value394): the end of sound394 plays sound312.
func _voice_finished() -> void:
	var finished := voice_clip
	voice_clip = 0
	if finished == int(src.control.first_sound): play(int(src.control.follow_sound))
