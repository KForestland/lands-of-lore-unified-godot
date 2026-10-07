extends CanvasLayer
signal ended(reason: String)
const Review = preload("res://scripts/lol2/cave_video_review.gd")
# Verified cave portion. Museum introductions belong to the destination map.
const STORY_CLIPS := [0, 3]
var story_index := 0
var story_clips: Array = STORY_CLIPS.duplicate()
var story_title := "Draracle’s chamber"

static func story_assets_ready(clips: Array = STORY_CLIPS) -> bool:
	if clips.is_empty(): return false
	for index in clips:
		if not index is int or index < 0 or index >= Review.CLIPS.size(): return false
		if not FileAccess.file_exists(Review.clip_path(index)):
			return false
	return true

var story_mode := false
var result := "interrupted"

var review: Control
var previous_pause := false
var previous_mouse := Input.MOUSE_MODE_VISIBLE
var session_tree: SceneTree

func _ready() -> void:
	if story_mode and not story_assets_ready(story_clips):
		result = "unavailable"
		queue_free()
		return
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	session_tree = get_tree()
	previous_pause = session_tree.paused
	previous_mouse = Input.mouse_mode
	session_tree.paused = true
	review = load("res://scenes/lol2/cave_video_review.tscn").instantiate()
	review.embedded = true
	review.story_mode = story_mode
	review.story_title = story_title
	if story_mode: review.initial_clip = story_clips[0]
	review.close_requested.connect(close)
	add_child(review)
	if story_mode:
		review.video.finished.connect(_story_finished)

func close() -> void:
	result = "skipped" if story_mode else "closed"
	review.video.stop()
	queue_free()

func _story_finished() -> void:
	story_index += 1
	if story_index < story_clips.size():
		review.play_clip(story_clips[story_index])
		return
	result = "finished"
	queue_free()

func _exit_tree() -> void:
	if session_tree != null:
		session_tree.paused = previous_pause
		Input.mouse_mode = previous_mouse
	ended.emit(result)
