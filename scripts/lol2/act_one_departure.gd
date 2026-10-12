extends CanvasLayer
## Source exit polygons, seekable original movie and validated level8/entry1 handoff.
const State = preload("res://scripts/lol2/act_one_departure_state.gd")
const DESTINATION := "res://scenes/lol2/darker_jungle.tscn"
var host: Node3D
var data: Dictionary
var media: Dictionary
var picture: TextureRect
var voice: AudioStreamPlayer
var atlas: AtlasTexture
var page := -1
var queued := false
var presented := false
func state() -> Dictionary:
	if not host.quest_state.has("act_one_departure"): host.quest_state.act_one_departure = State.initial()
	return host.quest_state.act_one_departure
func _ready() -> void:
	host = get_parent()
	layer = 40
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/act_one_departure/departure.json"))
	media = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/act_one_departure/playback.json"))
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	picture = TextureRect.new()
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(picture)
	atlas = AtlasTexture.new()
	picture.texture = atlas
	voice = AudioStreamPlayer.new()
	voice.stream = AudioStreamWAV.load_from_file(media.audio)
	add_child(voice)
	restore()
func active() -> bool:
	return state().phase in ["movie","arrival"]
func inside() -> bool:
	var p: Vector3 = host.player.position
	var foot: float = p.y-host.FormBody.FOOT_OFFSET
	for region in data.regions:
		if foot < float(region.floor.min())-1 or foot > float(region.floor.max())+3: continue
		var points := PackedVector2Array()
		for point in region.polygon: points.append(Vector2(point[0],point[1]))
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),points): return true
	return false
func begin() -> bool:
	if get_tree().current_scene != host or not host.ready_for_review or get_tree().paused or host.flying or not host.player.is_on_floor() or not inside(): return false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or host.interface_hud.cursor_active or host.health <= 0: return false
	if (is_instance_valid(host.weapon_shop) and host.weapon_shop.active()) or host.monastery.active() or (is_instance_valid(host.magic_shop) and host.magic_shop.active()) or host.village_dialogue.active() or host.followup_dialogue.active(): return false
	if not State.begin(state()): return false
	restore()
	return true
func restore() -> void:
	# Returning to the source area retains local55 but rearms its repeat exit.
	if state().phase == "arrived": state().phase = "idle"
	queued = false
	voice.stop()
	visible = active()
	if active():
		presented = true
		host.jump_requested = false
		host.player.velocity = Vector3.ZERO
		host.set_physics_process(false)
		host.interface_hud.hide()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if state().phase == "movie":
			show_frame()
			voice.play(float(state().elapsed))
	elif presented:
		presented = false
		host.set_physics_process(true)
		host.interface_hud.show()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func show_frame() -> void:
	var frame := mini(int(float(state().elapsed)*15),317)
	var next_page := frame/16
	if page != next_page:
		page = next_page
		atlas.atlas = ImageTexture.create_from_image(Image.load_from_file(media.atlases[page]))
	atlas.region = Rect2((frame%4)*640,((frame%16)/4)*400,640,400)
func advance(delta: float) -> void:
	State.advance(state(),delta)
	if state().phase == "movie": show_frame()
func _process(delta: float) -> void:
	if get_tree().paused or get_tree().current_scene != host: return
	if state().phase == "idle":
		begin()
	elif state().phase == "movie":
		advance(delta)
	if state().phase == "arrival" and not queued:
		queued = true
		finish.call_deferred()
func finish() -> void:
	if not is_inside_tree() or state().phase != "arrival" or get_tree().current_scene != host: return
	var transfer: Dictionary = host.area_handoff()
	transfer.quests.act_one_departure.phase = "arrived"
	var error: String = host.Save.Quests.validate(transfer.quests)
	if error.is_empty(): error = host.Save.validate_inventory(transfer.inventory)
	if not error.is_empty(): push_error(error); return
	get_tree().set_meta("lol2_darker_handoff",transfer)
	var status := get_tree().change_scene_to_file(DESTINATION)
	if status != OK:
		get_tree().remove_meta("lol2_darker_handoff")
		push_error("Could not load darker jungle: %s" % status)
func _input(event: InputEvent) -> void:
	if not active() or not event is InputEventKey or not event.pressed: return
	if event.keycode == KEY_F5: host.quicksave()
	elif event.keycode == KEY_F9: host.quickload()
	get_viewport().set_input_as_handled()
