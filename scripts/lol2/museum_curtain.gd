extends Node3D
## Museum curtain = static assembly / control81 (docs/museum-curtain.md). Mode byte selects the template60 child:
## 0 closed (descriptor181), 1 drawing (group 61-68), 2 gathered (descriptor180). Empty-hand use (kind4 value0):
## owner state 0 -> g7036 mode1 + sound347; state 1 -> g7100 mode1 + sound346. The end of the drawing (kind6 value2):
## state 0 -> g7076 mode2, state1; state 1 -> g7152 mode0, state0. Saved as "museum_curtain".
const SOURCE := "res://scripts/lol2/museum_curtain_source.json"
## Adapter: the group's native playback clock is not replayed; the Museum's authored surface rate.
const FPS := 8.0
const FRAMES := 8

var host: Node3D
var src: Dictionary = {}
var owner_state := 0
var mode := 0
var clock := 0.0
var mesh: MeshInstance3D
var material: StandardMaterial3D
var textures: Dictionary = {}
var voice: AudioStreamPlayer3D

static func source() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	return data if data is Dictionary else {}

static func assets_ready() -> bool:
	var data := source()
	if data.is_empty(): return false
	for file in data.images:
		if FileAccess.get_sha256(str(data.root) + file) != str(data.images[file]): return false
	for id in data.audio:
		if FileAccess.get_sha256(data.audio[id].path) != str(data.audio[id].wav_sha256): return false
	return true

static func initial() -> Dictionary:
	return {"version":1, "owner_state":0, "mode":0, "clock":0.0}

static func validate(state: Variant) -> String:
	if not state is Dictionary or state.size() != 4 or not state.has_all(["version", "owner_state", "mode", "clock"]): return "Invalid curtain state."
	for key in ["version", "owner_state", "mode"]:
		if not (state[key] is int or state[key] is float) or float(state[key]) != floorf(float(state[key])): return "Invalid curtain state."
	if int(state.version) != 1 or not (state.clock is int or state.clock is float) or not is_finite(float(state.clock)): return "Invalid curtain state."
	var pair := [int(state.owner_state), int(state.mode)]
	if not pair in [[0, 0], [0, 1], [1, 2], [1, 1]]: return "Invalid curtain state."
	if float(state.clock) < 0 or float(state.clock) >= FRAMES / FPS or (int(state.mode) != 1 and float(state.clock) != 0.0): return "Invalid curtain state."
	return ""

func setup(owner_host: Node3D, saved: Variant) -> String:
	host = owner_host
	name = "MuseumCurtain"
	src = source()
	if src.is_empty(): return "Curtain source missing."
	for file in src.images:
		textures[file] = ImageTexture.create_from_image(Image.load_from_file(str(src.root) + file))
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Adapter: one source face hangs in a walk-through doorway; drawn from both sides.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0, 1, 2, 0, 2, 3]:
		surface.set_uv(Vector2(src.uv[i][0], src.uv[i][1]))
		surface.add_vertex(Vector3(src.points[i][0], src.points[i][1], src.points[i][2]))
	surface.generate_normals()
	mesh = MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = material
	add_child(mesh)
	voice = AudioStreamPlayer3D.new()
	voice.position = aim_point()
	add_child(voice)
	var proposed: Variant = saved if saved != null else initial()
	return restore(proposed if validate(proposed).is_empty() else initial())

func checkpoint() -> Dictionary:
	return {"version":1, "owner_state":owner_state, "mode":mode, "clock":clock}

func restore(saved: Variant) -> String:
	var proposed: Variant = saved if saved != null else initial()
	var error := validate(proposed)
	if not error.is_empty(): return error
	owner_state = int(proposed.owner_state)
	mode = int(proposed.mode)
	clock = float(proposed.clock)
	voice.stop()
	present()
	return ""

func aim_point() -> Vector3:
	var sum := Vector3.ZERO
	for p in src.points: sum += Vector3(p[0], p[1], p[2])
	return sum / 4.0

## Drawing frame: forward while opening (state 0), reversed while closing (state 1).
func frame() -> int:
	var step := mini(int(clock * FPS), FRAMES - 1)
	return step if owner_state == 0 else FRAMES - 1 - step

func present() -> void:
	match mode:
		0: material.albedo_texture = textures["closed.png"]
		2: material.albedo_texture = textures["gathered.png"]
		_: material.albedo_texture = textures["drawing_%d.png" % frame()]

## Modern adapter: E prompt; the original has no on-screen prompt for the curtain.
func interaction_hint() -> String:
	if str(host.hand_item) != "" or mode == 1 or not host.can_reach_item(aim_point()): return ""
	return "E — Open curtain" if owner_state == 0 else "E — Close curtain"

## Kind4 value0 (empty hand). op5 to the current mode is a no-op natively (0x5D510 compares first); the sound replays.
func use() -> bool:
	if str(host.hand_item) != "" or not host.can_reach_item(aim_point()): return false
	var group: Dictionary = src.groups.open_use if owner_state == 0 else src.groups.close_use
	if mode != 1:
		mode = 1
		clock = 0.0
	play(int(src.sounds.open) if owner_state == 0 else int(src.sounds.close))
	present()
	return not group.is_empty()

func play(id: int) -> void:
	var clip: AudioStream = AudioStreamWAV.load_from_file(src.audio[str(id)].path)
	if clip == null: return
	voice.stream = clip
	voice.play()

func step(delta: float) -> void:
	if mode != 1 or not is_finite(delta) or delta <= 0: return
	clock += delta
	if clock >= FRAMES / FPS:
		# Kind6 value2: g7076 (mode2, state1) or g7152 (mode0, state0).
		clock = 0.0
		if owner_state == 0:
			mode = 2
			owner_state = 1
		else:
			mode = 0
			owner_state = 0
	present()
