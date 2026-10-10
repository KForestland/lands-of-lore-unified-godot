extends MeshInstance3D
## In-world animated object with a witnessed hit-to-first-stage binding.
## Keep the initial state until a gameplay event explicitly selects another frame.
signal stage_finished(stage: int)
signal expired
var failed := false
var final_wait := 25.0
var activated := false
var escaped := false
var stage_wait := 0.0
var stages: Array = []
var active_stage := -1
var stage_elapsed := 0.0
var stage_playing := false
var frame := 0
var current_page := -1
const ROOT := "res://assets/lol2/generated/museum_hourglass/"
static func assets_ready() -> bool:
	for page in range(3):
		if not FileAccess.file_exists(ROOT + "animation_%d.png" % page): return false
	return FileAccess.file_exists(ROOT + "stages.json") and FileAccess.file_exists(ROOT + "hourglass.json") and FileAccess.file_exists(ROOT + "hourglass.png")
func _ready() -> void:
	stages = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "stages.json")).stages
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "hourglass.json"))
	name = "MuseumHourglass226"
	position = Vector3(data.position[0], data.position[1], data.position[2])
	var quad := QuadMesh.new()
	quad.size = Vector2(data.size[0], data.size[1])
	quad.center_offset.y = float(data.size[1]) / 2.0
	mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT + "hourglass.png"))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material_override = material

func set_animation_frame(index: int) -> void:
	assert(index >= 0 and index < 300)
	frame = index
	var page := index / 100
	var material := material_override as StandardMaterial3D
	if page != current_page:
		current_page = page
		material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT + "animation_%d.png" % page))
	material.uv1_scale = Vector3(0.1, 0.1, 1.0)
	material.uv1_offset = Vector3(float(index % 10) / 10.0, float((index % 100) / 10) / 10.0, 0.0)

# Stage entry point; the scheduler owns progression.
func play_stage(index: int) -> bool:
	if index < 0 or index >= stages.size() or stage_playing: return false
	active_stage = index
	stage_elapsed = 0.0
	stage_playing = true
	set_animation_frame(int(stages[index].first))
	return true

func _process(delta: float) -> void:
	if failed: return
	# Source delay range20..30; interpreting units as seconds is provisional tuning.
	# Source final event is failure; final interval uses the same provisional range.
	while activated and not escaped and active_stage < 3 and delta >= stage_wait:
		advance_animation(stage_wait)
		delta -= stage_wait
		play_stage(active_stage + 1)
		stage_wait = float(randi_range(20,30)) if active_stage < 3 else 0.0
		if active_stage == 3: final_wait = float(randi_range(20,30))
	if activated and not escaped and active_stage < 3: stage_wait -= delta
	advance_animation(delta)
	if activated and not escaped and active_stage == 3:
		final_wait = maxf(0,final_wait-delta)
		if final_wait == 0:
			failed = true
			expired.emit()

func advance_animation(delta: float) -> void:
	if not stage_playing: return
	var stage: Dictionary = stages[active_stage]
	var count := int(stage.last) - int(stage.first) + 1
	stage_elapsed = minf(stage_elapsed + delta, float(count) / 15.0)
	set_animation_frame(int(stage.first) + mini(int(stage_elapsed * 15.0), count - 1))
	if stage_elapsed >= float(count) / 15.0:
		stage_playing = false
		stage_finished.emit(active_stage)

# Native opcode8/property10 selects a VQA section (verified command decoder path).
# Used by the witnessed start adapter and restoration scheduler.
func apply_stage_command(command: PackedByteArray) -> bool:
	if command.size() != 8: return false
	if command[0] != 8 or command[1] != 3 or command.decode_u16(2) != 226: return false
	if command[4] != 10 or command[5] != 0: return false
	return play_stage(command.decode_s16(6))

# Original hit witness selects group4620 / opcode8 property10 stage0.
# Timer clock and recovery presentation are restoration choices.
func receive_hit() -> bool:
	if activated or get_tree().paused: return false
	if not apply_stage_command(PackedByteArray([8,3,226,0,10,0,0,0])): return false
	activated = true
	stage_wait = float(randi_range(20,30))
	return true

func finish_escape() -> bool:
	if not activated or escaped or failed: return false
	escaped = true
	return true

func checkpoint() -> Dictionary:
	return {"final_wait":final_wait,"escaped": escaped, "activated": activated, "elapsed": stage_elapsed if activated else 0.0,
		"stage": active_stage if activated else -1, "wait": stage_wait if activated else 0.0}

func restore_checkpoint(state: Dictionary) -> void:
	failed = false
	final_wait = float(state.get("final_wait",25.0))
	activated = state.get("activated", false)
	escaped = state.get("escaped", false)
	stage_elapsed = float(state.get("elapsed", 0.0)) if activated else 0.0
	active_stage = int(state.get("stage", 0)) if activated else -1
	# Legacy first-stage saves receive a deterministic remaining interval.
	stage_wait = float(state.get("wait", 25.0 - stage_elapsed)) if activated and active_stage < 3 else 0.0
	if activated and active_stage < 3: stage_wait = maxf(stage_wait, 5.0 - stage_elapsed)
	stage_playing = activated and stage_elapsed < 5.0
	set_animation_frame(active_stage * 75 + mini(int(stage_elapsed * 15.0), 74) if activated else 0)
