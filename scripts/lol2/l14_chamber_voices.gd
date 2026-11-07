extends Node3D
## STORY-066 Chamber of Voices (L14 -> L16). Original CHV room (room30, CHV.MIX): background frame 30, the voices movie,
## the golden-chalice hotspot0 (194,88,396,218 on 640x400), speaker2 cue28, the CITY movie, then local22
## go_to_level_16 = 1 and the native prop170 kind-6 event (caller 0x14, group 9210 predicate 50) whose opcode 2 arm 0x1C
## changes to level 16 arrival 1. Sources: docs/l14-chamber-voices.md (Astra), tools/prepare_l14_chamber_voices.py.
## Adapters (DEVIATIONS): E on Chamber door 78/79 after Belial (actor 90) is dead opens the room (native door predicate
## 207 writer not traced); the Dreamstone may be carried, not only held; a click or E on the chalice offers it.
const KEY := "l14_chamber_voices"
const ROOT := "res://assets/lol2/generated/l14_chamber_voices/"
const DREAMSTONE := "act2:L13_RC:dreamstone"
const DOORS := [Vector3(688,40,10873), Vector3(638,40,10752)]
const HOTSPOT := Rect2(194,88,202,130)
const Items = preload("res://scripts/lol2/act2_items_catalog.gd")
var host: Node3D
var room: CanvasLayer
var panel: Control
var video: VideoStreamPlayer
var cue: AudioStreamPlayer
var hint: Label
var note: Label
var inside := false
var phase := ""  # "voices", "idle", "city"

static func initial() -> Dictionary: return {"version":1,"offered":false}
static func validate(s: Variant, quests: Dictionary) -> String:
	if not s is Dictionary or s.size() != 2 or s.get("version") != 1 or not s.get("offered") is bool: return "Invalid Chamber of Voices state."
	return ""
static func assets_ready() -> bool:
	for f in ["background.png","voices.ogv","city.ogv","cue_2_28.wav"]:
		if not FileAccess.file_exists(ROOT+f): return false
	return true
static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l14_chamber_voices.gd").new(); n.host = map; n.name = "L14ChamberVoices"; map.add_child(n); return n

func state() -> Dictionary: return host.quest_state.get(KEY, initial())

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var canvas := CanvasLayer.new(); canvas.layer = 34; add_child(canvas)
	hint = Label.new(); hint.position = Vector2(24,430); canvas.add_child(hint)
	if not assets_ready(): return
	room = CanvasLayer.new(); room.layer = 95; room.visible = false; add_child(room)
	var black := ColorRect.new(); black.color = Color.BLACK; black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); room.add_child(black)
	panel = Control.new(); panel.size = Vector2(640,400); room.add_child(panel)
	var background := TextureRect.new(); background.size = Vector2(640,400)
	background.texture = ImageTexture.create_from_image(Image.load_from_file(ROOT+"background.png")); panel.add_child(background)
	video = VideoStreamPlayer.new(); video.size = Vector2(640,400); video.expand = true; video.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_child(video)
	video.finished.connect(_movie_finished)
	note = Label.new(); note.position = Vector2(20,372); note.size = Vector2(600,24); note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; panel.add_child(note)
	cue = AudioStreamPlayer.new(); cue.stream = AudioStreamWAV.load_from_file(ROOT+"cue_2_28.wav"); add_child(cue)

func belial_dead() -> bool:
	var actors: Dictionary = host.act2_creatures.state.actors if host.get("act2_creatures") != null else {}
	return actors.has("90") and float(actors["90"].get("health",1)) <= 0

func door_in_reach() -> bool:
	if inside or host.flying or not host.starting_magic.world_active(): return false
	for p: Vector3 in DOORS:
		var d: Vector3 = p - host.camera.global_position
		if d.length() < 130 and d.length() > 0.01 and (-host.camera.global_basis.z).dot(d.normalized()) > 0.7: return true
	return false

func carried_dreamstone() -> String:
	if host.hand_item == DREAMSTONE or Items.definition(str(host.hand_item)) == 136: return str(host.hand_item)
	for id in host.carried_collected:
		if id == DREAMSTONE or Items.definition(str(id)) == 136: return str(id)
	return ""

## The door: E after Belial's defeat opens the Chamber of Voices.
func open_room() -> bool:
	if not assets_ready() or not door_in_reach(): return false
	if not belial_dead():
		host.save_feedback("The Chamber of Voices stays sealed while Belial's guardian lives."); return true
	inside = true; room.visible = true; get_tree().paused = true
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if state().offered:
		_travel(); return true
	_play("voices", ROOT+"voices.ogv")
	note.text = "Click the chalice — Offer the Dreamstone   ·   Esc — Leave"
	return true

func _play(name: String, path: String) -> void:
	phase = name
	var stream := VideoStreamTheora.new(); stream.file = path; video.stream = stream; video.visible = true; video.play()

func _movie_finished() -> void:
	if phase == "voices":
		phase = "idle"; video.visible = false
	elif phase == "city":
		phase = ""; _travel()

## The chalice (hotspot0). Without the Dreamstone the voices refuse; nothing is lost.
func offer() -> Dictionary:
	if not inside or phase == "city": return {"ok":false,"reason":""}
	if state().offered: return {"ok":false,"reason":"The chalice already holds the Dreamstone."}
	var item := carried_dreamstone()
	if item.is_empty():
		note.text = "The voices wait for the Dreamstone."; return {"ok":false,"reason":"The voices wait for the Dreamstone."}
	host.carried_collected.erase(item)
	if host.hand_item == item: host.hand_item = ""
	var s := state().duplicate(true); s.offered = true; host.quest_state[KEY] = s
	Items.sync(host)
	cue.play(); note.text = ""
	_play("city", ROOT+"city.ogv")
	return {"ok":true,"reason":"The Dreamstone is destroyed in the chalice."}

func skip() -> void:
	if phase in ["voices","city"]: video.stop(); _movie_finished()

func leave() -> void:
	if not inside or phase == "city": return
	inside = false; room.visible = false; video.stop(); phase = ""; get_tree().paused = false
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Native continuation: local22 go_to_level_16 = 1, then prop170's kind-6 record (caller 0x14) -> group 9210 -> L16 arrival 1.
func _travel() -> void:
	inside = false; room.visible = false; video.stop(); phase = ""; get_tree().paused = false
	if DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	host.progression.native.call("set_local", 22, 1)
	host.progression.fire("prop:170", 6, {"caller_byte":0x14})

func _process(_delta: float) -> void:
	hint.text = ""
	if inside and is_instance_valid(panel):
		var viewport := get_viewport().get_visible_rect().size; var scale_by := minf(viewport.x/640, viewport.y/400)
		panel.scale = Vector2.ONE*scale_by; panel.position = (viewport-panel.size*scale_by)/2
	elif door_in_reach() and assets_ready():
		hint.text = "E — Enter the Chamber of Voices"

func _input(event: InputEvent) -> void:
	if not inside: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = (event.position - panel.position) / panel.scale.x
		if HOTSPOT.has_point(local): offer()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if phase == "city": skip()
			else: leave()
		elif event.keycode in [KEY_SPACE, KEY_ENTER]: skip()
		elif event.keycode == KEY_E: offer()
		else: return
	else: return
	get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if inside or event is not InputEventKey or not event.pressed or event.echo or event.keycode != KEY_E: return
	if open_room(): get_viewport().set_input_as_handled()
