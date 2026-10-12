extends Node
## User-confirmed headfake: a shout, with no pursuing guards.
## Original Glad_Hey_you recording; first-deck trigger remains authored.
const DURATION := 3.0
const VOICE_ROOT := "res://assets/lol2/bridge_warning/"
var host: Node3D
var played := false
var remaining := 0.0
var subtitle: Label
var voice: AudioStreamPlayer
var bounds := AABB()

func setup(walkthrough: Node3D) -> void:
	host = walkthrough
	voice = AudioStreamPlayer.new()
	add_child(voice)
	var manifest_path := VOICE_ROOT + "provenance.json"
	if FileAccess.file_exists(manifest_path):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		var path := VOICE_ROOT + "hey_you.wav"
		if manifest is Dictionary and FileAccess.get_sha256(path) == manifest.get("wav_sha256", ""):
			voice.stream = AudioStreamWAV.load_from_file(path)
	if voice.stream == null:
		push_warning("Bridge warning voice is missing or changed; subtitle remains available.")
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/river_deck/deck.json"))
	var deck: Dictionary = source.records[0]
	assert(int(deck.index) == 56)
	var p: Array = deck.native_xyz
	var b: Array = deck.bounds_xyz
	# Godot coordinates: X, height, -native planar Y. Capsule centre is32
	# above the five-unit-thick deck. Eight-unit tolerance excludes riverbed.
	bounds = AABB(Vector3(p[0]+b[0], p[2]+b[5]+24, -(p[1]+b[3])),
		Vector3(b[1]-b[0], 16, b[3]-b[2]))
	var layer := CanvasLayer.new()
	layer.layer = 22
	add_child(layer)
	subtitle = Label.new()
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle.offset_left = -220
	subtitle.offset_right = 220
	subtitle.offset_top = -120
	subtitle.offset_bottom = -72
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_shadow_color", Color.BLACK)
	subtitle.add_theme_constant_override("shadow_offset_x", 2)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	subtitle.text = "Hey, you!"
	subtitle.hide()
	layer.add_child(subtitle)

func tick(delta: float) -> void:
	var running: bool = not host.drowning.dead and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	voice.stream_paused = not running
	if not played and running and not host.flying and host.player.is_on_floor():
		if bounds.has_point(host.player.global_position-host.native_translation):
			played = true
			remaining = DURATION
			if voice.stream != null:
				remaining = maxf(DURATION, voice.stream.get_length())
				voice.play()
	elif running:
		remaining = maxf(0.0, remaining-delta)
	subtitle.visible = remaining > 0.0 and not host.drowning.dead

func dismiss() -> void:
	# Checkpoint recovery keeps the one-time event consumed, like bridge cuts.
	remaining = 0.0
	voice.stop()
	subtitle.hide()
