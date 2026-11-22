extends Node3D
## Control 186, template 27, movie E056E.VQA, at native (-669, 4216). Two Huline women.
## Kind 5 group 26572 sets property 10 = 1 (loiter) and property 7 = 255 (loop).
## Aimed E follows property 10: segment 0, then 2, then 4, then opcode 9 property 2 hides them.
## Adapter: flags 0x1402 include bit 0x1000. The only link is prop 4620 event 6 value 265
## (group 17322, opcode 9 property 3). That producer is unread, so they start present.
## No command writes owner state 1, so the first E runs the state==1 group (segment 0, state 2).
## Opcode 16 stores that state. It is not a segment id. The strike group 26702 stays unread.
const MEDIA := "res://assets/lol2/generated/jungle_cat_ladies/"
const SHADER := preload("res://scripts/lol2/jungle_bacatta65.gd").SHADER
const ANCHOR := Vector3(-669.0, 0.0, -4216.0)
const SIZE := Vector2(140.0, 87.0)
const REACH := 140.0
const LOITER := 1
var host: Node3D
var media: Dictionary = {}
var present_flag: bool = true
var segment: int = LOITER
var elapsed: float = 0.0
var passes: int = 255
var owner_state: int = 0
var mesh: MeshInstance3D
var voice: AudioStreamPlayer3D
var voice_segment: int = -1
var voice_elapsed: float = -1.0
var textures: Dictionary = {}

static func assets_ready() -> bool:
	return FileAccess.file_exists(MEDIA + "media.json")

func initial() -> Dictionary:
	return {"version": 1, "present": true, "segment": LOITER, "elapsed": 0.0, "passes": 255, "owner_state": 0}

## The segment clock is animation only. A save keeps the segment and restarts its loop, so a save that
## is written again after a reload is the same file (F5/F9 round trip, quest handoffs).
func checkpoint() -> Dictionary:
	return {"version": 1, "present": present_flag, "segment": segment, "elapsed": 0.0, "passes": passes, "owner_state": owner_state}

static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size() != 6: return "Invalid cat ladies packet."
	if not _whole(packet.get("version"), 1, 1): return "Invalid cat ladies packet."
	if not packet.get("present") is bool: return "Invalid cat ladies flag."
	if not _whole(packet.get("segment"), -1, 4): return "Invalid cat ladies segment."
	if not _whole(packet.get("passes"), 0, 255): return "Invalid cat ladies passes."
	if not _whole(packet.get("owner_state"), 0, 5): return "Invalid cat ladies state."
	var clock: Variant = packet.get("elapsed")
	if not (clock is int or clock is float) or not is_finite(float(clock)) or float(clock) < 0.0: return "Invalid cat ladies clock."
	if not bool(packet.present) and (int(packet.segment) != -1 or float(clock) != 0.0): return "Absent cat ladies are still playing."
	return ""

static func _whole(value: Variant, lo: int, hi: int) -> bool:
	if value is int: return int(value) >= lo and int(value) <= hi
	if value is float and is_finite(float(value)) and floorf(float(value)) == float(value): return int(value) >= lo and int(value) <= hi
	return false

func setup(owner_host: Node3D, saved: Variant = null) -> String:
	host = owner_host
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MEDIA + "media.json"))
	if not parsed is Dictionary: return "Cat ladies media missing (run tools/prepare_jungle_cat_ladies_media.py)."
	media = parsed
	mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = SIZE
	quad.center_offset = Vector3(0.0, SIZE.y * 0.5, 0.0)
	mesh.mesh = quad
	var shader := Shader.new()
	shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.material_override = material
	add_child(mesh)
	voice = AudioStreamPlayer3D.new()
	voice.stream = AudioStreamWAV.load_from_file(MEDIA + "voice.wav")
	voice.unit_size = 300.0
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	voice.max_distance = 1200.0
	add_child(voice)
	return restore(initial() if saved == null else saved)

func restore(packet: Variant) -> String:
	var error := validate(packet)
	if not error.is_empty(): return error
	present_flag = bool(packet.present)
	segment = int(packet.segment)
	elapsed = float(packet.elapsed)
	passes = int(packet.passes)
	owner_state = int(packet.owner_state)
	voice.stop()
	voice_segment = -1
	voice_elapsed = -1.0
	show_frame()
	return ""

func origin() -> Vector3:
	var offset: Variant = host.get("native_translation")
	return offset if offset is Vector3 else Vector3.ZERO

## Owner r18 14-47-36: at height 0 the women stood in the ground. The clearing floor is higher; stand them on the
## first floor hit under the anchor (cached once the world has collision; 0 until then).
var ground_y: float = NAN
func anchor() -> Vector3:
	var place: Vector3 = ANCHOR + origin()
	if is_nan(ground_y) and is_inside_tree():
		var top: Vector3 = place + Vector3(0.0, 200.0, 0.0)
		var query := PhysicsRayQueryParameters3D.create(top, place - Vector3(0.0, 200.0, 0.0), 1)
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): ground_y = (hit.position as Vector3).y
	if not is_nan(ground_y): place.y = ground_y
	return place

func live() -> bool:
	return is_instance_valid(host.starting_magic) and host.starting_magic.world_active() and not get_tree().paused

## The movie is a flat billboard, not a movement solid. A look toward its middle, inside reach,
## counts. A layer-1 wall between the camera and that point refuses the talk.
func aimed() -> bool:
	if not present_flag or segment < 0 or not live(): return false
	var eye: Vector3 = host.camera.global_position
	var mid: Vector3 = anchor() + Vector3.UP * (SIZE.y * 0.5)
	var to: Vector3 = mid - eye
	var dist: float = to.length()
	if dist > REACH or dist < 0.1: return false
	if to.dot(-host.camera.global_basis.z) / dist < 0.65: return false
	var wall := PhysicsRayQueryParameters3D.create(eye, mid, 1, [host.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(wall).is_empty()

## First E runs the owner-state==1 group. Later E presses run the value-0 groups for states 2, 3 and 4.
func offer() -> bool:
	if not aimed(): return false
	if owner_state == 0:
		play_segment(0, 2)
		return true
	if owner_state == 2:
		play_segment(2, 3)
		return true
	if owner_state == 3:
		play_segment(4, 4)
		return true
	if owner_state == 4:
		hide_ladies()
		return true
	return false

func play_segment(next_segment: int, next_state: int) -> void:
	segment = next_segment
	elapsed = 0.0
	passes = 0
	owner_state = next_state
	voice_elapsed = -1.0
	show_frame()

func hide_ladies() -> void:
	present_flag = false
	segment = -1
	elapsed = 0.0
	passes = 0
	voice.stop()
	voice_segment = -1
	show_frame()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and offer():
		get_viewport().set_input_as_handled()

func advance(delta: float) -> void:
	voice.stream_paused = not live()
	if not live() or not is_finite(delta) or delta <= 0.0 or not present_flag or segment < 0: return
	elapsed += delta
	var row: Dictionary = media.segments[segment]
	var duration: float = float(row.duration)
	if passes == 255:
		if elapsed >= duration:
			elapsed = fmod(elapsed, duration)
			voice_elapsed = -1.0
	elif elapsed > duration:
		elapsed = duration
	show_frame()

func show_frame() -> void:
	var place := anchor()
	mesh.global_position = place
	voice.global_position = place
	var showing := present_flag and segment >= 0
	mesh.visible = showing
	if not showing:
		voice.stop()
		voice_segment = -1
		return
	var row: Dictionary = media.segments[segment]
	var first: int = int(row.first)
	var last: int = int(row.last)
	var frame: int = mini(last, first + int(elapsed * 15.0))
	if not textures.has(frame):
		if textures.size() > 90: textures.clear()
		textures[frame] = ImageTexture.create_from_image(Image.load_from_file(MEDIA + str(media.frames[frame])))
	mesh.material_override.set_shader_parameter("frame", textures[frame])
	if voice_segment != segment or elapsed < voice_elapsed:
		voice_segment = segment
		voice.play(float(first) / 15.0 + elapsed)
	voice_elapsed = elapsed
	voice.stream_paused = not live()

func _physics_process(delta: float) -> void:
	advance(delta)
