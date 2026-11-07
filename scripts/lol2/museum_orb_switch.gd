extends Node3D
## Source sprites and region1249 moving floor. Movable65's reset uses the original
## running timer. Sound 701 is the raise-group request 0x02BD (stone6.aud).
## Command tail bytes 0x80 and 0x0A14 are not mapped onto Godot attenuation.
## The moving plate is an AnimatableBody3D with sync_to_physics left false.
## Museum steps it at the start of the physics tick, before the player moves.
## Idle processing stays off so that step is not applied twice.
## Orb selector frames, opcode 197 markers and template37 stay open.
const FloorState = preload("res://scripts/lol2/museum_orb_floor_state.gd")
var floor_state := FloorState.initial()
const SOURCE := "res://scripts/lol2/museum_orb_switch_source.json"
const ROOT := "res://assets/lol2/generated/museum_orb_switch/"
const FLOOR_SOUND := "res://assets/lol2/generated/hive_boulder_audio/701.wav"
const PIT_FACE := 3307
var host: Node3D
var source: Dictionary = {}
var raised := false
var aim := Vector3(-2095, 0, -1085)
var lowered_body: StaticBody3D
var raised_body: StaticBody3D
var orb: MeshInstance3D
var crystal: MeshInstance3D
var floor_audio: AudioStreamPlayer3D
var floor_sound_plays: int = 0

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "orb.png") and FileAccess.file_exists(ROOT + "crystal.png") and FileAccess.file_exists(FLOOR_SOUND)

static func pit_face() -> int:
	return PIT_FACE

static func initial() -> Dictionary: return FloorState.initial()

static func validate(value: Variant) -> String: return FloorState.validate(value)

func setup(owner: Node3D, saved: Variant = null) -> String:
	name = "MuseumOrbSwitch"
	host = owner
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not parsed is Dictionary: return "Invalid orb-switch source."
	source = parsed
	if int(source.get("version", 0)) != 1: return "Invalid orb-switch source."
	var pit: Dictionary = source.pit
	if int(pit.face_index) != PIT_FACE or int(pit.region) != 1249 or str(pit.kind) != "floor": return "Unexpected pit face."
	var points: Array = pit.points
	if points.size() != 4: return "Unexpected pit points."
	for point in points:
		if not is_equal_approx(float(point[1]), float(pit.lowered_y)): return "Pit source is not lowered."
	if not is_equal_approx(float(pit.lowered_y), -50.0) or not is_equal_approx(float(pit.raised_y), 30.0): return "Unexpected pit heights."
	var plate: Array = source.plate.aim
	aim = Vector3(float(plate[0]), float(plate[1]), float(plate[2]))
	orb = _billboard(source.orb, "Orb")
	crystal = _billboard(source.crystal, "Crystal")
	add_child(orb)
	add_child(crystal)
	lowered_body = _floor(0.0, "Lowered", false)
	raised_body = _floor(0.0, "MovingFloor", true)
	add_child(lowered_body)
	add_child(raised_body)
	var clip: AudioStream = AudioStreamWAV.load_from_file(FLOOR_SOUND)
	if clip == null: return "Floor sound 701 did not load."
	floor_audio = AudioStreamPlayer3D.new()
	floor_audio.name = "FloorSound"
	floor_audio.stream = clip
	floor_audio.position = aim
	# Reach-sized falloff. Not the source command's 0x80 / 0x0A14 tail.
	floor_audio.unit_size = 96.0
	floor_audio.max_distance = 700.0
	add_child(floor_audio)
	set_process(false)
	return restore_checkpoint(saved)

func checkpoint() -> Dictionary:
	return floor_state.duplicate(true)

func restore_checkpoint(saved: Variant) -> String:
	var error := validate(saved)
	if not error.is_empty(): return error
	floor_state = FloorState.restore(saved)
	present()
	return ""

func _billboard(row: Dictionary, node_name: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var quad := QuadMesh.new()
	quad.size = Vector2(float(row.right) - float(row.left), float(row.top) - float(row.bottom))
	quad.center_offset = Vector3((float(row.right) + float(row.left)) / 2.0, (float(row.top) + float(row.bottom)) / 2.0, 0)
	mesh.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT + str(row.file)))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mesh.material_override = material
	var place: Array = row.position
	mesh.position = Vector3(float(place[0]), float(place[1]), float(place[2]))
	return mesh

func _floor(shift: float, node_name: String, platform: bool) -> StaticBody3D:
	var body: StaticBody3D
	if platform:
		var moving: AnimatableBody3D = AnimatableBody3D.new()
		# True defers the body until the physics sync and drops the intermediate ray.
		moving.sync_to_physics = false
		body = moving
	else:
		body = StaticBody3D.new()
	body.name = node_name
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collision := PackedVector3Array()
	var points: Array = source.pit.points
	var uv: Array = source.pit.uv
	for i in [0, 1, 2, 0, 2, 3]:
		var p: Array = points[i]
		var vertex := Vector3(float(p[0]), float(p[1]) + shift, float(p[2]))
		if uv.size() == 4:
			var t: Array = uv[i]
			st.set_uv(Vector2(float(t[0]), float(t[1])))
		else:
			st.set_uv(Vector2.ZERO)
		st.add_vertex(vertex)
		collision.append(vertex)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = host.materials.get(str(source.pit.material))
	body.add_child(mesh)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(collision)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	return body

func present() -> void:
	raised = bool(floor_state.local20)
	_show_body(lowered_body, false)
	_show_body(raised_body, true)
	_place_moving_floor()

func _place_moving_floor() -> void:
	raised_body.position.y = float(floor_state.height) - FloorState.LOW

func _physics_process(_delta: float) -> void:
	# Re-apply inside the physics tick. An idle write updates the node and
	# leaves the kinematic query behind until this step.
	_place_moving_floor()

func _show_body(body: StaticBody3D, show: bool) -> void:
	body.visible = show
	for child in body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not show

func _ready_for_use() -> bool:
	if not is_instance_valid(host) or host.get_tree().paused or host.introduction_state != "complete": return false
	if is_instance_valid(host.interface_hud) and host.interface_hud.cursor_active: return false
	return host.starting_magic == null or host.starting_magic.world_active()

## Empty-hand kind4 only. A carried key that is not in the hand does not count. Lock insert stays on the key owner.
func use() -> bool:
	if not _ready_for_use() or raised or str(host.hand_item) != "": return false
	if not host.can_reach_item(aim): return false
	if not FloorState.use(floor_state): return false
	present()
	_play_floor_sound()
	if host.has_method("save_feedback"): host.save_feedback("The floor plate rises.")
	return true

## Group 12284 sound request 14204100bd0280000a14. One shot per accepted raise.
func _play_floor_sound() -> void:
	if floor_audio == null or floor_audio.stream == null: return
	floor_audio.play()
	floor_sound_plays += 1

func interaction_hint() -> String:
	if not _ready_for_use() or raised or str(host.hand_item) != "": return ""
	if host.can_reach_item(aim): return "E — Raise the floor plate"
	return ""

## One floor step. The walkthrough calls this before move_and_slide.
## A direct _process call remains for tests that freeze the walkthrough.
func step_motion(delta: float) -> void:
	if not is_instance_valid(host) or host.get_tree().paused or host.introduction_state != "complete": return
	if host.starting_magic != null and not host.starting_magic.world_active(): return
	if FloorState.advance(floor_state, delta): present()

func _process(delta: float) -> void:
	step_motion(delta)
