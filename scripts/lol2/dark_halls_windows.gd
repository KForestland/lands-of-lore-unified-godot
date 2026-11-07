extends Node
## Dark Halls "Windows opened n/7" puzzle (scripts/lol2/dark_halls_windows_source.json): the 15 template35 windows in
## the domed hall ring. Each window's event6 group adds 1 to local5; at local5 > 6 the orb (prop242) ends: soul +1,
## the 18 grid SHADEs (op13 sub17) are gone, and window 246 breaks open as the way out (exit regions open).
## Modern adapters (docs/DEVIATIONS.md): a window opens on a Spark hit or E within reach; the orb end runs at once
## (the native waits for sound 546); opened windows are drawn as a glow and a light shaft. State:
## quests.dark_halls_windows {"opened": [controls], "done": bool}.
const SOURCE := "res://scripts/lol2/dark_halls_windows_source.json"
const REACH := 150.0
const FACING := 0.8
const HUD_RADIUS := 1000.0
const Shared = preload("res://scripts/lol2/shared_global_defaults.gd")
var host: Node3D
var source: Dictionary = {}
var by_control: Dictionary = {}
var centre := Vector3.ZERO
var glows: Dictionary = {}
var counter: Label
var counter_hold := 0.0

class Receiver:
	extends RefCounted
	var owner_node: Node
	var control: int
	func _init(node: Node, id: int) -> void: owner_node = node; control = id
	func receive_spark() -> bool: return owner_node.open_window(control)

static func assets_ready() -> bool: return FileAccess.file_exists(SOURCE)

func setup(walkthrough: Node3D) -> String:
	name = "DarkHallsWindows"
	host = walkthrough
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not parsed is Dictionary: return "Dark Halls windows source missing."
	source = parsed
	for w in source.windows:
		by_control[int(w.control)] = w
		centre += _vec(w.center)
	centre /= float(source.windows.size())
	for w in source.windows: _add_receiver(w)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	counter = Label.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"])
	counter.add_theme_font_override("font", font)
	counter.add_theme_font_size_override("font_size", 26)
	counter.add_theme_color_override("font_color", Color(0.86, 0.84, 0.80))
	counter.add_theme_color_override("font_outline_color", Color.BLACK)
	counter.add_theme_constant_override("outline_size", 4)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	counter.offset_left = -320.0; counter.offset_right = -18.0; counter.offset_top = 8.0
	counter.visible = false
	layer.add_child(counter)
	return ""

static func _vec(a: Array) -> Vector3: return Vector3(float(a[0]), float(a[1]), float(a[2]))

func state() -> Dictionary:
	var quests: Dictionary = host.quest_state
	if not quests.get("dark_halls_windows") is Dictionary: quests.dark_halls_windows = {"opened": [], "done": false}
	return quests.dark_halls_windows

static func validate(value: Variant, src: Dictionary) -> String:
	if not value is Dictionary or value.size() != 2 or not value.get("opened") is Array or not value.get("done") is bool: return "Invalid Dark Halls windows."
	var known: Array = []
	for w in src.windows: known.append(int(w.control))
	var seen: Dictionary = {}
	for c in value.opened:
		if not (c is int or c is float) or float(c) != floor(float(c)) or not int(c) in known or seen.has(int(c)): return "Invalid Dark Halls windows."
		seen[int(c)] = true
	if bool(value.done) != (value.opened.size() >= int(src.target)): return "Invalid Dark Halls windows."
	return ""

## Reads do not create the entry (loading must not change the quests).
func _saved() -> Dictionary:
	var saved: Variant = host.quest_state.get("dark_halls_windows")
	return saved if saved is Dictionary else {"opened": [], "done": false}

func opened() -> Array:
	var result: Array = []
	for c in _saved().opened: result.append(int(c))
	return result

func done() -> bool: return bool(_saved().done)

## Facing normal of a window's pane (horizontal, toward the dome side).
func _inward(w: Dictionary) -> Vector3:
	var edge := _vec(w.front[1]) - _vec(w.front[0])
	var normal := Vector3(edge.z, 0.0, -edge.x).normalized()
	return normal if normal.dot(centre - _vec(w.center)) >= 0.0 else -normal

## Pane width/height from the front face.
static func _pane(w: Dictionary) -> Vector2:
	var a := _vec(w.front[0]); var b := _vec(w.front[1]); var c := _vec(w.front[2])
	return Vector2(Vector2(b.x - a.x, b.z - a.z).length(), absf(b.y - c.y))

func _add_receiver(w: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "Window%d" % int(w.control)
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var pane := _pane(w)
	box.size = Vector3(maxf(pane.x, 30.0), maxf(pane.y, 30.0), 6.0)
	shape.shape = box
	body.add_child(shape)
	body.set_meta("spark_receiver", Receiver.new(self, int(w.control)))
	add_child(body)
	var inward := _inward(w)
	body.global_position = _vec(w.center) - inward * 4.0
	body.look_at(body.global_position + inward, Vector3.UP)

## The unopened window in front of the camera within reach, or -1.
func aimed_window() -> int:
	var cam: Camera3D = host.camera
	var best := -1
	var best_dot := FACING
	for w in source.windows:
		if int(w.control) in opened(): continue
		var offset := _vec(w.center) - cam.global_position
		if offset.length() > REACH: continue
		var dot := (-cam.global_basis.z).dot(offset.normalized())
		if dot > best_dot: best_dot = dot; best = int(w.control)
	return best

## Event6 group of one window: local5 += 1 and its lit look; the target count runs the orb end.
func open_window(control: int) -> bool:
	if done() or not by_control.has(control) or control in opened(): return false
	state().opened.append(control)
	_light(by_control[control])
	counter_hold = 4.0
	_update_counter()
	if opened().size() >= int(source.target): finish()
	elif host.has_method("save_feedback"): host.save_feedback("The window opens and light falls in.")
	return true

## Orb end group (g2082): GV_LUTHERS_SOUL += 1, the grid SHADEs gone, orb gone; window 246 breaks open.
func finish() -> void:
	if done(): return
	state().done = true
	var monastery: Dictionary = host.quest_state.get("monastery", {})
	if monastery.get("globals") is Dictionary:
		var globals: Dictionary = monastery.globals
		Shared.add_soul(globals, int(source.orb.soul_delta))  # SOUL-SYSTEM: clamped 0..10
	_remove_shades()
	_present_end()
	counter_hold = 6.0
	_update_counter()
	if host.has_method("save_feedback"): host.save_feedback("The dark orb shatters. A window breaks open to the jungle.")

func _remove_shades() -> void:
	var pop = host.get("creatures")
	if pop == null or not is_instance_valid(pop): return
	var State = preload("res://scripts/lol2/scripted_creature_state.gd")
	for id in source.orb.shades:
		if pop.state.actors.has(id) and int(pop.state.actors[id].health) > 0:
			State.damage(pop.state, pop.src, id, int(pop.state.actors[id].health))
	pop.sync_quests()
	pop.present()

func _present_end() -> void:
	var orb = host.get("prop_nodes")
	if orb is Dictionary and orb.has(int(source.orb.prop)): orb[int(source.orb.prop)].visible = false
	var exit_window: Dictionary = by_control.get(int(source.exit.window), {})
	if not exit_window.is_empty(): _light(exit_window, true)

## Re-apply the saved state (load, handoff).
func restore_from_quests() -> void:
	for key in glows.keys():
		for node in glows[key]: node.queue_free()
	glows.clear()
	for control in opened(): _light(by_control[control])
	var orb = host.get("prop_nodes")
	if orb is Dictionary and orb.has(int(source.orb.prop)): orb[int(source.orb.prop)].visible = not done()
	if done(): _present_end()
	_update_counter()

func _material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = colour
	return m

## Lit window: a bright pane over the glass and a shaft of light into the dome. Broken (exit) window: jungle green.
func _light(w: Dictionary, broken: bool = false) -> void:
	var key := "%d%s" % [int(w.control), "b" if broken else ""]
	if glows.has(key): return
	var inward := _inward(w)
	var size := _pane(w)
	var width := size.x
	var pane := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size * (1.15 if broken else 1.02)
	if broken:
		var view := StandardMaterial3D.new()
		view.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		view.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		view.cull_mode = BaseMaterial3D.CULL_DISABLED
		view.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		view.albedo_texture = _jungle_view()
		quad.material = view
	else:
		quad.material = _material(Color(1.0, 0.93, 0.7, 1.0))
	pane.mesh = quad
	add_child(pane)
	pane.global_position = _vec(w.center) + inward * (12.0 if broken else 3.5)
	pane.look_at(pane.global_position + inward, Vector3.UP)
	var nodes: Array = [pane]
	if not broken:
		var shaft := MeshInstance3D.new()
		var beam := BoxMesh.new()
		beam.size = Vector3(width * 0.8, size.y * 0.8, 320.0)
		beam.material = _material(Color(1.0, 0.95, 0.8, 0.12))
		shaft.mesh = beam
		add_child(shaft)
		var start := _vec(w.center) + inward * 4.0
		var finish_point := start + inward * 320.0 + Vector3(0, -110.0, 0)
		shaft.global_position = (start + finish_point) / 2.0
		shaft.look_at(finish_point, Vector3.UP)
		nodes.append(shaft)
	glows[key] = nodes

## Modern stand-in for the broken wall's view out (the original shows the jungle through a ragged hole): sky over
## foliage, ragged transparent edge. Deterministic noise so every run draws the same picture.
func _jungle_view() -> ImageTexture:
	var image := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 246
	for y in 48:
		for x in 64:
			var edge := mini(mini(x, 63 - x), mini(y, 47 - y))
			if edge < 4 and rng.randf() < 0.75 - edge * 0.18: image.set_pixel(x, y, Color(0, 0, 0, 0)); continue
			var horizon := 18 + int(4.0 * sin(x * 0.35)) + rng.randi_range(-1, 1)
			var colour: Color
			if y < horizon: colour = Color("487f9d").lerp(Color("c8d5c4"), float(y) / float(horizon))
			else: colour = Color(0.12, 0.38 + rng.randf() * 0.25, 0.10 + rng.randf() * 0.08)
			image.set_pixel(x, y, colour)
	return ImageTexture.create_from_image(image)

func _update_counter() -> void:
	if counter == null: return
	counter.text = "Windows opened:\n%d/%d" % [mini(opened().size(), int(source.target)), int(source.target)]

func _process(delta: float) -> void:
	if counter == null or host == null or not is_instance_valid(host.player): return
	counter_hold = maxf(counter_hold - delta, 0.0)
	var p: Vector3 = host.player.global_position
	var near := Vector2(p.x - centre.x, p.z - centre.z).length() < HUD_RADIUS and p.y > centre.y - 200.0
	counter.visible = counter_hold > 0.0 or (near and not done())

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or get_tree().paused or host.flying: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		var control := aimed_window()
		if control >= 0 and open_window(control): get_viewport().set_input_as_handled()
