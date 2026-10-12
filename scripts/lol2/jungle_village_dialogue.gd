extends MeshInstance3D
## Source control99 section0 and local15 completion. Modern playback/movement lock.
const State = preload("res://scripts/lol2/jungle_village_state.gd")
const ROOT := "res://assets/lol2/generated/jungle_village_dialogue/"
var asset_root := ROOT
var data: Dictionary
var frame := 415
var page := -1
var pages: Dictionary = {}
var audio: AudioStreamPlayer3D
static func assets_ready() -> bool:
	for asset in ["conversation.json","section_0.wav","page_0.png","page_1.png","page_2.png","page_3.png","page_4.png","page_5.png"]:
		if not FileAccess.file_exists(ROOT+asset): return false
	return true
func state() -> Dictionary:
	var gate = get_parent().village_gate.state()
	if not gate.has("dialogue"):
		gate.dialogue = State.dialogue_initial()
		# Older gate checkpoints predate dialogue; preserve their completed admission.
		if gate.local24 == 1:
			gate.dialogue.started = true
			gate.dialogue.elapsed = State.SPEECH_DURATION
			gate.dialogue.local15 = 1
	return gate.dialogue
func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(asset_root + "conversation.json"))
	position = Vector3(data.position[0], data.position[1], data.position[2])
	var quad := QuadMesh.new()
	quad.size = Vector2(data.size[0], data.size[1])
	quad.center_offset.y = quad.size.y / 2
	quad.center_offset.x = float(data.get("center_offset_x",0))
	mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material_override = material
	audio = AudioStreamPlayer3D.new()
	audio.unit_size = 120
	add_child(audio)
	restore()
func active() -> bool:
	return state().started and state().local15 == 0
func begin() -> bool:
	if get_parent().village_gate.state().local24 != 1 or state().started or state().local46 != 0 or get_tree().paused: return false
	state().started = true
	state().elapsed = 0.0
	state().local15 = 0
	get_parent().player.velocity = Vector3.ZERO
	restore()
	return true
func restore() -> void:
	if not is_instance_valid(audio): return
	audio.stop()
	visible = state().local46 == 0
	if active():
		_set_frame(mini(414,int(float(state().elapsed)*15)))
		audio.stream = AudioStreamWAV.load_from_file(ROOT+"section_0.wav")
		audio.play(float(state().elapsed))
	else:
		_set_frame(415)
func _process(delta: float) -> void:
	advance(delta)
func advance(delta: float) -> void:
	if get_tree().paused or not active() or get_parent().health <= 0: return
	state().elapsed = minf(State.SPEECH_DURATION,float(state().elapsed)+maxf(delta,0))
	_set_frame(mini(414,int(float(state().elapsed)*15)))
	if state().elapsed == State.SPEECH_DURATION:
		state().local15 = 1 # Source completion group21174.
		audio.stop()
		_set_frame(415)
func _set_frame(index: int) -> void:
	frame = index
	var next_page := index / 100
	if page != next_page:
		page = next_page
		if not pages.has(page): pages[page] = ImageTexture.create_from_image(Image.load_from_file(asset_root + "page_%d.png" % page))
		material_override.albedo_texture = pages[page]
	material_override.uv1_scale = Vector3(0.1,0.1,1)
	material_override.uv1_offset = Vector3(float(index%10)/10,float((index%100)/10)/10,0)

