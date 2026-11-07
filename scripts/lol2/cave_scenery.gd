extends Node3D
## L1_DC ambient scenery omitted by the recovered prop preview (G44, CAVE_OVERVIEW_20261028 item 4) and the Cave-arrival
## positional sound emitters (G45), from cave_scenery_source.json (tools/prepare_cave_scenery.py).
## Props: wall torches 73 (state0 holder + the F1A94 chained state1 flame at the same anchor), meat 48, jungle mist 90,
## waterfalls 81, water pillars 0/2/3 and shrinktofit 65. Each is drawn at its native box (left/right/bottom/top, the
## static-preview rule) as an indexed layer-2 billboard mirrored into the mask pass, like cave_lava_flames.gd.
## frame_seconds 0.1 = owner-trial adapter rate (native rate UNKNOWN); null = first frame only. No collision, nothing saved.
## Emitters: event6 value9 owner records whose opcode-20 command names the owner itself. Their native trigger is UNKNOWN
## (G45: no runtime caller entered); the port starts them once the walkthrough is ready (adapter, DEVIATIONS).
const SOURCE := "res://scripts/lol2/cave_scenery_source.json"
const ROOT := "res://assets/lol2/generated/cave_scenery/"
## Adapter: the chained state is drawn just in front of its holder (billboard local +z faces the camera).
const CHAIN_DEPTH := 0.05
var host: Node3D
var source: Dictionary
var textures := {}  # material -> Array[ImageTexture]
var meshes := {}  # id or id + "chain" -> MeshInstance3D
var voices := {}  # emitter id -> AudioStreamPlayer3D
var clock := 0.0

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "741.wav")

func setup(walkthrough: Node3D) -> String:
	name = "CaveScenery"
	host = walkthrough
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not source is Dictionary or int(source.version) != 1: return "Invalid cave scenery source."
	for f in source.files:
		if FileAccess.get_sha256(ROOT + str(f)) != str(source.files[f]): return "Cave scenery media changed: " + str(f)
	for material in source.art:
		var frames: Array[ImageTexture] = []
		for f in source.art[material]: frames.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + str(f))))
		textures[material] = frames
	for id in source.props:
		var row: Dictionary = source.props[id]
		var at: Vector3 = Vector3(row.position[0], row.position[1], row.position[2]) + host.native_translation
		_billboard(id, row, at, 0.0)
		if row.has("chain"): _billboard(id + "chain", row.chain, at, CHAIN_DEPTH)
	for id in source.emitters:
		var e: Dictionary = source.emitters[id]
		var stream := AudioStreamWAV.load_from_file(ROOT + str(e.file))
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		var voice := AudioStreamPlayer3D.new(); voice.name = "Ambient" + id; voice.stream = stream; voice.unit_size = 64.0
		voice.position = Vector3(e.position[0], e.position[1], e.position[2]) + host.native_translation
		add_child(voice)
		voices[id] = voice
	present()
	return ""

func _billboard(id: String, row: Dictionary, at: Vector3, depth: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(float(row.right) - float(row.left), float(row.top) - float(row.bottom))
	quad.center_offset = Vector3((float(row.left) + float(row.right)) / 2.0, (float(row.bottom) + float(row.top)) / 2.0, depth)
	var mesh := MeshInstance3D.new(); mesh.mesh = quad; mesh.layers = 2; mesh.name = "Scenery" + id
	mesh.material_override = host._indexed_material(ROOT + str(row.frames[0]))
	mesh.material_override.set_shader_parameter("sprite", true)
	# Native 129AC8 setup: frame flag 0x40 reverses columns, 0x80 reverses rows.
	var flags := int(row.frame_flags) & 0xC0
	mesh.material_override.set_shader_parameter("uv_scale", Vector2(-1.0 if flags & 0x40 else 1.0, -1.0 if flags & 0x80 else 1.0))
	mesh.material_override.set_shader_parameter("uv_offset", Vector2(1.0 if flags & 0x40 else 0.0, 1.0 if flags & 0x80 else 0.0))
	mesh.position = at
	mesh.set_meta("material", str(row.material))
	add_child(mesh)
	if host.has_method("_copy_occluders"): host._copy_occluders(mesh)
	meshes[id] = mesh

## Starts the emitters once the walkthrough is ready (adapter; the native trigger is UNKNOWN).
func start_ambience() -> void:
	for id in voices:
		if not voices[id].playing: voices[id].play()

func frame_of(material: String) -> int:
	if source.frame_seconds == null: return 0
	return int(clock / float(source.frame_seconds)) % textures[material].size()

func present() -> void:
	for id in meshes:
		var mesh: MeshInstance3D = meshes[id]
		var material := str(mesh.get_meta("material"))
		var texture: ImageTexture = textures[material][frame_of(material)]
		if mesh.material_override.get_shader_parameter("indices") != texture:
			mesh.material_override.set_shader_parameter("indices", texture)
		if host.has_method("sync_render_source"): host.sync_render_source(mesh, texture)

func _world_active() -> bool:
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic): return host.starting_magic.world_active()
	return not host.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if not is_instance_valid(host) or not host.get("walkthrough_ready"): return
	start_ambience()
	if not _world_active() or not is_finite(delta) or delta <= 0: return
	if source.frame_seconds == null: return
	clock = fmod(clock + delta, 3600.0)
	present()
