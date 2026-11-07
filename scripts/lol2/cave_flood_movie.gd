extends CanvasLayer
## Full-screen FLOOD movie of prop83's g146 (op21 prop614 movie 29, cave_flood_source.json). The native op21 plays the
## movie over a frozen world; here the tree pauses while it runs (as cave_entrance_death.gd) and the host's
## video_overlay gate refuses saves/loads meanwhile. Escape or Space skips (presentation adapter, DEVIATIONS).
signal ended(reason: String)
const SOURCE := "res://scripts/lol2/cave_flood_source.json"
var video: VideoStreamPlayer
var previous_pause := false
var result := "interrupted"

static func movie_info() -> Dictionary:
	if not FileAccess.file_exists(SOURCE): return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not data is Dictionary or int(data.get("group", -1)) != 146 or int(data.get("op21", {}).get("movie", -1)) != 29: return {}
	var movie: Dictionary = data.movie
	return movie if FileAccess.file_exists(String(movie.path)) else {}

static func assets_ready() -> bool: return not movie_info().is_empty()

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var info := movie_info()
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	video = VideoStreamPlayer.new()
	video.set_anchors_preset(Control.PRESET_FULL_RECT)
	video.expand = true
	var stream := VideoStreamTheora.new()
	stream.file = String(info.get("path", ""))
	video.stream = stream
	video.finished.connect(func(): close("finished"))
	add_child(video)
	previous_pause = get_tree().paused
	get_tree().paused = true
	video.play()

func close(reason: String) -> void:
	if is_queued_for_deletion(): return
	result = reason
	if is_instance_valid(video): video.stop()
	get_tree().paused = previous_pause
	ended.emit(reason)
	queue_free()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_SPACE]:
		close("skipped")
		get_viewport().set_input_as_handled()
