extends MeshInstance3D
## Source sections in a review-only in-world conversation; admission is authored.
signal conversation_started
signal conversation_finished
const Quests = preload("res://scripts/lol2/act_one_quest_state.gd")
const ROOT := "res://assets/lol2/generated/hive_conversation/"
var data: Dictionary
# Source region1001/event4/group6598. Admission is authored, not a full opcode9 replay.
const ROOM_POLYGON := [Vector2(-1248,-8688),Vector2(-1271,-8721),Vector2(-1180,-8753),Vector2(-1175,-8740)]
var room_entered := false
var started := false
var completed := false
var shared_flags: Dictionary = {}
var section_cursor := 0
var elapsed := 0.0
var frame := 0
var page := -1
var audio: AudioStreamPlayer3D
var pages: Dictionary = {}
var locked_movement := false
var prompt: Label3D

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "conversation.json"))
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
	prompt = Label3D.new()
	prompt.text = "E — Speak"
	prompt.position.y = 140
	prompt.font_size = 32
	prompt.pixel_size = 0.3
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.visible = false
	add_child(prompt)
	_set_frame(242) # Source named loiter section; static until review interaction.

func can_begin() -> bool:
	if not room_entered or started or get_tree().paused: return false
	if get_parent().has_node("Warriors") and get_parent().get_node("Warriors").health <= 0: return false
	var review = get_parent()
	if not review.ready_for_review or review.flying: return false
	var target := global_position + Vector3(0,64,0)
	var camera: Camera3D = review.camera
	var offset := target-camera.global_position
	if offset.length() > 160 or offset.normalized().dot(-camera.global_basis.z) < 0.9: return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,target,1,[review.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and can_begin():
			begin()
			get_viewport().set_input_as_handled()

func begin() -> bool:
	if not room_entered or started or get_tree().paused: return false
	if get_parent().has_node("Warriors") and get_parent().get_node("Warriors").health <= 0: return false
	started = true
	shared_flags[38] = 1 # Original start-group writer, not completion reward.
	section_cursor = 0
	elapsed = 0
	get_parent().set_physics_process(false)
	locked_movement = true
	_enter_section()
	conversation_started.emit()
	return true

func _enter_section() -> void:
	var section: Dictionary = data.sections[int(data.order[section_cursor])]
	_set_frame(int(section.first))
	audio.stream = AudioStreamWAV.load_from_file(ROOT + section.audio)
	audio.play()

func _set_frame(index: int) -> void:
	frame = index
	var next_page := index / 100
	if page != next_page:
		page = next_page
		if not pages.has(page): pages[page] = ImageTexture.create_from_image(Image.load_from_file(ROOT + "page_%d.png" % page))
		material_override.albedo_texture = pages[page]
	material_override.uv1_scale = Vector3(0.1,0.1,1)
	material_override.uv1_offset = Vector3(float(index%10)/10,float((index%100)/10)/10,0)

func check_room_contact() -> void:
	var review = get_parent()
	if room_entered or get_tree().paused or not review.ready_for_review or review.flying: return
	var point: Vector3 = review.player.global_position
	# Review player position is the capsule centre. Reject other floors and debug flight.
	if point.y < -235 or point.y > -107: return
	if Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),PackedVector2Array(ROOM_POLYGON)):
		room_entered = true

func _process(delta: float) -> void:
	check_room_contact()
	prompt.visible = can_begin()
	advance(delta)

func advance(delta: float) -> void:
	if not started or completed or get_tree().paused: return
	var remaining := maxf(delta,0)
	while not completed:
		var section: Dictionary = data.sections[int(data.order[section_cursor])]
		var duration := float(section.last-section.first+1)/float(data.fps)
		var consumed := minf(remaining,duration-elapsed)
		elapsed += consumed
		remaining -= consumed
		_set_frame(int(section.first)+mini(int(elapsed*float(data.fps)),int(section.last-section.first)))
		if elapsed < duration: return
		audio.stop()
		if section_cursor == data.order.size()-1:
			completed = true
			if locked_movement:
				get_parent().set_physics_process(true)
				locked_movement = false
			conversation_finished.emit()
			return
		section_cursor += 1
		elapsed = 0
		_enter_section()
		if remaining == 0: return

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null
	if locked_movement and is_instance_valid(get_parent()):
		get_parent().set_physics_process(true)

func quest_checkpoint() -> Dictionary:
	return {"shared_flag_38":1 if started else 0,"hive_room_entered":room_entered,"conversation":{
		"started":started,"completed":completed,"section_cursor":section_cursor,"elapsed":elapsed}}

func restore_quest_checkpoint(state: Variant) -> String:
	var error := Quests.validate(state)
	if not error.is_empty(): return error
	# Validate before touching playback, flags or the movement lock.
	audio.stop()
	if locked_movement:
		get_parent().set_physics_process(true)
		locked_movement = false
	room_entered = state.get("hive_room_entered",state.conversation.started)
	started = state.conversation.started
	completed = state.conversation.completed
	section_cursor = int(state.conversation.section_cursor)
	elapsed = float(state.conversation.elapsed)
	shared_flags = {38:1} if started else {}
	prompt.visible = false
	if not started:
		_set_frame(242)
	elif completed:
		_set_frame(912)
	else:
		get_parent().set_physics_process(false)
		locked_movement = true
		_enter_section()
		var section: Dictionary = data.sections[int(data.order[section_cursor])]
		_set_frame(int(section.first)+int(elapsed*float(data.fps)))
		audio.play(elapsed)
	return ""
