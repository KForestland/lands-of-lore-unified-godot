extends Node3D
## Animated ambient props of the prop83 side chamber and the prop1362 splash sequencer (cave_side_chamber_source.json).
## The recovered prop preview omits animated props; these are drawn as indexed layer-2 billboards (the cave's visible
## index viewport) mirrored into its mask pass. Props 139-143 loop; props 557-564 play one splash when prop1362's
## 1 s timer draws their state (random 0..9; states 1..8 map to one prop each). No reward exists in the chamber.
const SOURCE := "res://scripts/lol2/cave_side_chamber_source.json"
const ROOT := "res://assets/lol2/generated/cave_side_chamber/"
var host: Node3D
var source: Dictionary
var meshes := {}
var textures := {}
var mirrored := {}
var clock := 0.0
var sequencer := 0.0
var splash := {}
var rng := RandomNumberGenerator.new()
var last_state := -1
var triggers := 0

static func assets_ready() -> bool: return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "prop_946_0_index.png")

func setup(walkthrough: Node3D, seed: int = 1362) -> void:
	name = "CaveSideChamber"
	host = walkthrough
	rng.seed = seed
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	for key in source.props:
		var row: Dictionary = source.props[key]
		var frames: Array[ImageTexture] = []
		for f in row.frames: frames.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + str(f))))
		textures[key] = frames
		var width: float = float(row.right) - float(row.left)
		var height: float = width * float(frames[0].get_height()) / float(frames[0].get_width())
		var quad := QuadMesh.new(); quad.size = Vector2(width, height)
		quad.center_offset = Vector3((float(row.left) + float(row.right)) / 2.0, height / 2.0, 0)
		var mesh := MeshInstance3D.new(); mesh.mesh = quad; mesh.layers = 2
		mesh.material_override = host._indexed_material(ROOT + str(row.frames[0]))
		mesh.material_override.set_shader_parameter("sprite", true)
		mesh.position = host.point(row.position) + host.native_translation
		add_child(mesh)
		meshes[key] = mesh
		var before: int = host.occluder_pairs.size()
		host._copy_occluders(mesh)
		if host.occluder_pairs.size() > before: mirrored[key] = host.occluder_pairs.back()

func _world_active() -> bool:
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic): return host.starting_magic.world_active()
	return not host.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _show(key: String, index: int) -> void:
	var tex: ImageTexture = textures[key][index]
	meshes[key].material_override.set_shader_parameter("indices", tex)
	if mirrored.has(key) and is_instance_valid(mirrored[key][1]): mirrored[key][1].material_override.set_shader_parameter("indices", tex)

## Event20 on a splash prop (op7 play): one pass through its frames from frame0.
func trigger(prop: int) -> void:
	splash[str(prop)] = 0.0
	_show(str(prop), 0)
	triggers += 1

## The prop1362 timer step: a random state 0..9; states 1..8 send property21 (event20) to one splash prop.
func sequence_step() -> void:
	last_state = rng.randi_range(0, int(source.sequencer.random_states) - 1)
	var order: Dictionary = source.sequencer.order
	if order.has(str(last_state)): trigger(int(order[str(last_state)]))

func _advance_splashes(delta: float) -> void:
	var step: float = float(source.frame_seconds)
	for key in splash.keys():
		splash[key] = float(splash[key]) + delta
		var index := int(float(splash[key]) / step)
		if index >= textures[key].size():
			splash.erase(key); _show(key, 0)
		else:
			_show(key, index)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	var step: float = float(source.frame_seconds)
	clock += delta
	for key in source.props:
		if str(source.props[key].mode) == "loop": _show(key, int(clock / step) % textures[key].size())
	var left := delta
	var period: float = float(source.sequencer.period_seconds)
	while left > 0.0:
		var consumed := minf(left, period - sequencer)
		_advance_splashes(consumed)
		sequencer += consumed
		left -= consumed
		if sequencer >= period:
			sequencer = 0.0
			sequence_step()
	for key in mirrored:
		var pair: Array = mirrored[key]
		if is_instance_valid(pair[1]) and pair[0].is_inside_tree() and pair[1].is_inside_tree(): pair[1].global_transform = pair[0].global_transform

func _process(delta: float) -> void:
	if not is_instance_valid(host) or not host.get("walkthrough_ready") or not _world_active(): return
	advance(delta)
