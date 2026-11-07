extends Control
signal close_requested
var embedded := false
var story_mode := false
var initial_clip := 0
var story_title := "Draracle’s chamber"

const CLIPS = [
	["Kenneth · Entry 6", "kevin_entry6.ogv"],
	["Kenneth · Entry 20", "kevin_entry20.ogv"],
	["Blue-screen clip · Entry 24", "bluescreen_entry24.ogv"],
	["Draracle · Cave discussion", "chamber_discussion.ogv"],
	["Draracle · Museum introduction 1", "museum_introduction_a.ogv"],
	["Draracle · Museum introduction 2", "museum_introduction_b.ogv"],
	["Dragon · Departure", "res://assets/lol2/generated/dragon_flight/dragon7.ogv"],
	["Dragon · Flight", "res://assets/lol2/generated/dragon_flight/drgnflgt.ogv"],
	["Dragon · Arrival", "res://assets/lol2/generated/dragon_flight/dragon8.ogv"],
]

static func clip_path(index: int) -> String:
	var file: String = CLIPS[index][1]
	return file if file.begins_with("res://") else "res://assets/lol2/video_review/" + file

var video: VideoStreamPlayer
var picker: OptionButton
var pause_button: Button
var status: Label
var selected := 0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("151719")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = story_title if story_mode else "Cave video review"
	column.add_child(title)
	picker = OptionButton.new()
	for clip in CLIPS: picker.add_item(clip[0])
	picker.item_selected.connect(play_clip)
	column.add_child(picker)
	picker.visible = not story_mode
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1.6
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(aspect)
	video = VideoStreamPlayer.new()
	video.expand = true
	video.finished.connect(_finished)
	aspect.add_child(video)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	pause_button = Button.new()
	pause_button.text = "Pause"
	pause_button.pressed.connect(toggle_pause)
	controls.add_child(pause_button)
	var replay := Button.new()
	replay.text = "Replay"
	replay.pressed.connect(func(): play_clip(selected))
	controls.add_child(replay)
	replay.visible = not story_mode
	var mute := CheckButton.new()
	mute.text = "Mute"
	mute.toggled.connect(func(value: bool): video.volume = 0.0 if value else 1.0)
	controls.add_child(mute)
	var close_button := Button.new()
	close_button.text = "Skip" if story_mode else "Return to cavern" if embedded else "Close"
	close_button.pressed.connect(close)
	controls.add_child(close_button)
	status = Label.new()
	column.add_child(status)
	status.visible = not story_mode
	var hint := Label.new()
	hint.text = "Space: pause/resume · Esc: skip" if story_mode else "Space: pause/resume · R: replay · Left/Right: change clip · Esc: close\nReview only — story triggers are not connected."
	column.add_child(hint)
	play_clip(initial_clip)

func play_clip(index: int) -> void:
	selected = posmod(index, CLIPS.size())
	picker.select(selected)
	video.stop()
	video.paused = false
	var path := clip_path(selected)
	if not FileAccess.file_exists(path):
		status.text = "This review clip is missing."
		pause_button.disabled = true
		return
	var stream := VideoStreamTheora.new()
	stream.file = path
	video.stream = stream
	video.play()
	pause_button.disabled = false
	pause_button.text = "Pause"
	status.text = "Playing · " + CLIPS[selected][0]

func toggle_pause() -> void:
	if pause_button.disabled: return
	if not video.is_playing():
		play_clip(selected)
		return
	video.paused = not video.paused
	pause_button.text = "Resume" if video.paused else "Pause"
	status.text = ("Paused · " if video.paused else "Playing · ") + CLIPS[selected][0]

func _finished() -> void:
	pause_button.text = "Play again"
	status.text = "Finished · " + CLIPS[selected][0]

func close() -> void:
	video.stop()
	if embedded: close_requested.emit()
	else: get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if story_mode and event.keycode in [KEY_R, KEY_LEFT, KEY_RIGHT]:
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_SPACE: toggle_pause()
		KEY_R: play_clip(selected)
		KEY_LEFT: play_clip(selected - 1)
		KEY_RIGHT: play_clip(selected + 1)
		KEY_ESCAPE: close()
		_: return
	get_viewport().set_input_as_handled()
