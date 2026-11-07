extends CanvasLayer
## The Cave waterfall room CFALL on the Cave host (owner reports 2026-10-20 11:11, 10-23 19:45, 10-24 17:35: the
## "2D point-and-click" spot). Grounded entry into region 1815/1817/1818 runs op12 room 32; the room shows the looping
## CFALL_ background, the two pool hotspots drink (heal 5 and two quips), Back/Escape leaves and the entry region's
## op18 places the player outside. The world is paused while the room is open (the native room loop owns the frame),
## and the host's video_overlay gate refuses saves, loads and world consumers meanwhile. Effects: cave_cfall.gd.
signal closed
const Cfall = preload("res://scripts/lol2/cave_cfall.gd")
const Body = preload("res://scripts/lol2/player_form_body.gd")
var host: Node3D
var src: Dictionary = {}
var state: Dictionary = Cfall.initial()
var region := -1
var was_inside := true
var queue: Array = []
var background: VideoStreamPlayer
var voice: AudioStreamPlayer
var canvas: Control
var back: Button
var root_control: Control

static func assets_ready() -> bool:
	var data := Cfall.source()
	if data.is_empty() or not FileAccess.file_exists(String(data.background.path)): return false
	for cue in data.cues.values():
		if not FileAccess.file_exists(String(cue.path)): return false
	return true

func setup(cave: Node3D) -> String:
	host = cave
	src = Cfall.source()
	if src.is_empty(): return "Missing CFALL source."
	name = "CaveCfallRoom"
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control = Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_control)
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(backdrop)
	canvas = Control.new()
	canvas.size = Vector2(640,400)
	root_control.add_child(canvas)
	background = VideoStreamPlayer.new()
	background.expand = true
	background.size = canvas.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.finished.connect(func(): if active(): background.play())
	canvas.add_child(background)
	canvas.gui_input.connect(_canvas_input)
	back = Button.new()
	back.text = "Back"
	back.position = Vector2(550,365)
	back.size = Vector2(80,28)
	back.pressed.connect(leave_room)
	canvas.add_child(back)
	voice = AudioStreamPlayer.new()
	add_child(voice)
	voice.finished.connect(_next)
	root_control.resized.connect(_layout)
	_layout()
	visible = false
	return ""
func _layout() -> void:
	if not is_instance_valid(canvas): return
	var size: Vector2 = root_control.size
	var factor := minf(size.x/640.0,size.y/400.0)
	canvas.scale = Vector2.ONE*factor
	canvas.position = (size-Vector2(640,400)*factor)/2.0

func checkpoint() -> Dictionary: return Cfall.canonical(state)
func restore(saved: Variant) -> String:
	var value = Cfall.initial() if saved == null else saved
	var error := Cfall.validate(value)
	if not error.is_empty(): return error
	if active(): _close()
	state = Cfall.canonical(value)
	# A load puts the player wherever the save says; a save inside an entry region must not reopen the room at once.
	was_inside = true
	return ""
func active() -> bool: return region >= 0
func speaking() -> bool: return not queue.is_empty() or (is_instance_valid(voice) and voice.playing)

## Region event 2 for one physics step of the host. Returns true when the room opened.
func advance(point: Vector3, grounded: bool) -> bool:
	if src.is_empty() or active(): return false
	var entered := Cfall.region_at(src, Vector2(point.x, point.z), point.y - Body.FOOT_OFFSET) if grounded else -1
	var inside := entered >= 0
	var edge := inside and not was_inside
	was_inside = inside
	return edge and enter_room(entered)

## op12 room 32: callback 1 (hotspots), then callback 9 (ambient, first-visit quip).
func enter_room(entry_region: int) -> bool:
	if active() or src.is_empty(): return false
	if host.get("video_overlay") != null and is_instance_valid(host.video_overlay): return false
	region = entry_region
	if "video_overlay" in host: host.video_overlay = self
	if "interaction_requested" in host: host.interaction_requested = false
	host.player.velocity = Vector3.ZERO
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	var stream := VideoStreamTheora.new()
	stream.file = String(src.background.path)
	background.stream = stream
	background.play()
	_run(Cfall.first_update(state, src))
	return true
## Message 8: Back or Escape (only between lines, as the other hosted rooms).
func leave_room() -> bool:
	if not active() or speaking(): return false
	var leaving := region
	_close()
	for effect in Cfall.leave(src, leaving):
		if effect[0] == "place": _place(int(effect[1]), int(effect[2]), float(effect[3]))
	return true
func _close() -> void:
	queue.clear()
	voice.stop()
	background.stop()
	background.stream = null
	visible = false
	region = -1
	if "video_overlay" in host and host.video_overlay == self: host.video_overlay = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
## op18 player placement (flags 0x0885, height 0): native (x, y) at the floor under that point, facing the op18 heading
## (yaw = -heading * TAU / 65536, the Cave arrival rule). The floor search starts from the walking elevation, as the
## guard encounter's op18 does.
func _place(x: int, y: int, yaw: float) -> void:
	var target: Vector3 = host.native_translation+Vector3(x, 0, -y)
	target.y = host.player.global_position.y-Body.FOOT_OFFSET
	var ray := PhysicsRayQueryParameters3D.create(target+Vector3.UP*64,target-Vector3.UP*512,1,[host.player.get_rid()])
	var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): target.y = hit.position.y
	host.player.global_position = target+Vector3.UP*Body.FOOT_OFFSET
	host.player.velocity = Vector3.ZERO
	host.player.rotation = Vector3(0, yaw, 0)
	if host.get("camera") != null: host.camera.rotation = Vector3.ZERO
	# The placement point lies outside the three entry regions; the next entry needs a new step in.
	was_inside = false

## Applies host effects in order; a movie(2, line, 24) cue holds the rest until its audio ends.
func _run(effects: Array) -> void:
	queue.append_array(effects)
	back.disabled = true
	if not voice.playing: _next()
func _next() -> void:
	while not queue.is_empty():
		var effect: Array = queue.pop_front()
		match effect[0]:
			"set_flag": state.flags[str(effect[1])] = 1
			"heal":
				var magic = host.get("starting_magic")
				if magic != null and is_instance_valid(magic): magic.set_health(Cfall.heal(magic.health(), int(effect[1])))
			"movie":
				var cue: Dictionary = src.cues.get("%d:%d" % [int(effect[1]), int(effect[2])], {})
				if cue.is_empty(): continue
				voice.stream = AudioStreamWAV.load_from_file(String(cue.path))
				voice.play()
				return
			_: pass # hotspot / ambient_start: geometry is static here; ambient 344 is not hosted (DEVIATIONS).
	back.disabled = false
func click(point: Vector2i) -> bool:
	if not active() or speaking(): return false
	var hotspot := Cfall.hotspot_at(src, point)
	var effects := Cfall.click(hotspot, src)
	if effects.is_empty(): return false
	_run(effects)
	return true
func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if click(Vector2i(event.position)): canvas.accept_event()
func _unhandled_key_input(event: InputEvent) -> void:
	if not active() or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_ESCAPE:
		leave_room()
		get_viewport().set_input_as_handled()
## Enter skips the cue now playing (dialogue_skip.gd).
func skip_line() -> bool:
	if not active() or not voice.playing: return false
	voice.stop()
	_next()
	return true
