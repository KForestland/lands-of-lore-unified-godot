extends Node
## Cave entrance death (docs/cave-entrance-death.md, owner report 2026-10-17 10:45:34). Control135 is a template21
## support plate across the cave mouth. Native ADA30 admits entry event 8 for the human, 9 for the beast, 7 for the
## lizard while the plate's owner state is 0 (predicate206); each group sets the state, kills the player at once
## (op2 sub0x39 -> D8D48) and plays that form's full-screen death movie (op21 74 luthrdie / 11 bst-die / 35 liz-die).
## Native recovery is a save reload with the plate state 0 again, so the state is not saved and every reset or load
## re-arms the plate. Grounded foot admission is the shared source_control_contact.gd adapter.
signal movie_finished(reason: String)
const SOURCE := "res://scripts/lol2/cave_entrance_death_source.json"
const Contact = preload("res://scripts/lol2/source_control_contact.gd")
const Body = preload("res://scripts/lol2/player_form_body.gd")

var host: Node
var src: Dictionary = {}
var contact: Dictionary = Contact.initial()
var owner_state := 0
var played: Array = []
var overlay: CanvasLayer
var video: VideoStreamPlayer

static func assets_ready() -> bool:
	if not FileAccess.file_exists(SOURCE): return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not data is Dictionary: return false
	for movie in data.get("movies", {}).values():
		if not FileAccess.file_exists(String(movie.path)): return false
	return true

func setup(cave: Node) -> String:
	host = cave
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not data is Dictionary or int(data.get("control", -1)) != 135: return "Invalid Cave entrance death source."
	var records: Array = []
	for row in data.records: records.append({"value": int(row.value), "group": int(row.group), "movie": int(row.movie)})
	src = {"plates": [{"id": 135, "polygon": data.polygon, "height": float(data.height), "records": records}], "movies": data.movies}
	return ""

## Re-arms the plate (R recovery, checkpoint load, save load).
func reset() -> void:
	contact = Contact.initial()
	owner_state = 0

func playing() -> bool: return is_instance_valid(overlay)

## One physics step of the plate. Returns the admitted record ({} when nothing happened).
func advance(point: Vector3, grounded: bool, form: int) -> Dictionary:
	if src.is_empty() or playing(): return {}
	for effect in Contact.update(contact, src, Vector2(point.x, point.z), point.y - Body.FOOT_OFFSET, grounded, form, {"135": owner_state}):
		if effect.groups.is_empty(): continue
		for row in src.plates[0].records:
			if int(row.value) != int(effect.value): continue
			owner_state = 1
			played.append(int(row.movie))
			return row
	return {}

func play(movie: int) -> bool:
	var info: Dictionary = src.movies.get(str(movie), {})
	if info.is_empty() or not FileAccess.file_exists(String(info.path)): return false
	overlay = CanvasLayer.new()
	overlay.layer = 100
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(backdrop)
	video = VideoStreamPlayer.new()
	video.set_anchors_preset(Control.PRESET_FULL_RECT)
	video.expand = true
	var stream := VideoStreamTheora.new()
	stream.file = String(info.path)
	video.stream = stream
	video.finished.connect(func(): _close("finished"))
	overlay.add_child(video)
	add_child(overlay)
	get_tree().paused = true
	video.play()
	return true

func _close(reason: String) -> void:
	if not is_instance_valid(overlay): return
	video.stop()
	overlay.queue_free()
	overlay = null
	get_tree().paused = false
	movie_finished.emit(reason)

func _unhandled_key_input(event: InputEvent) -> void:
	if playing() and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_SPACE]:
		_close("skipped")
		get_viewport().set_input_as_handled()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Native point (x, h, y) inside the plate polygon.
func inside(point: Vector3) -> bool:
	if src.is_empty(): return false
	var polygon := PackedVector2Array()
	for p in src.plates[0].polygon: polygon.append(Vector2(p[0], p[1]))
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), polygon)
