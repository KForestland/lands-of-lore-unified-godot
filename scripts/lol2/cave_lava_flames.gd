extends Node3D
## L1_DC lava-chamber flames: templates 69/70/71, props 281..328 (tools/prepare_cave_lava_flames.py), omitted by the
## recovered prop preview (playtest 2026-10-17 report11:03:19 looks across the chamber below the roach nest).
## Ambient only: the source attaches no command group, hit record or region to them. Each is drawn at its source
## state size (width byte x height byte, the rule the tar fires use) from descriptor126's seven frames; nothing is saved.
const SOURCE := "res://scripts/lol2/cave_lava_flames_source.json"
const ROOT := "res://assets/lol2/generated/cave_lava_flames/"
const FPS := 10.0
var host: Node3D
var source: Dictionary
var sprites := {}
var textures: Array[ImageTexture] = []
var clock := 0.0

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "126_0_index.png")

func setup(walkthrough: Node3D) -> String:
	name = "CaveLavaFlames"
	host = walkthrough
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not source is Dictionary or int(source.version) != 1: return "Invalid lava flames source."
	for f in source.frames:
		if FileAccess.get_sha256(ROOT + str(f)) != str(source.files[f]): return "Lava flame art changed: " + str(f)
		textures.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + str(f))))
	for id in source.props:
		var row: Dictionary = source.props[id]
		var quad := QuadMesh.new()
		quad.size = Vector2(float(row.right) - float(row.left), float(row.top) - float(row.bottom))
		quad.center_offset = Vector3((float(row.left) + float(row.right)) / 2.0, (float(row.bottom) + float(row.top)) / 2.0, 0)
		var mesh := MeshInstance3D.new(); mesh.mesh = quad; mesh.layers = 2; mesh.name = "LavaFlame" + id
		mesh.material_override = host._indexed_material(ROOT + str(source.frames[0]))
		mesh.material_override.set_shader_parameter("sprite", true)
		mesh.position = Vector3(row.position[0], row.position[1], row.position[2]) + host.native_translation
		add_child(mesh)
		if host.has_method("_copy_occluders"): host._copy_occluders(mesh)
		sprites[id] = mesh
	present()
	return ""

func frame_of(id: String) -> int:
	return (int(source.props[id].start_frame) + int(clock * FPS)) % textures.size()

func present() -> void:
	for id in sprites:
		var texture: ImageTexture = textures[frame_of(id)]
		var mesh: MeshInstance3D = sprites[id]
		mesh.material_override.set_shader_parameter("indices", texture)
		if host.has_method("sync_render_source"): host.sync_render_source(mesh, texture)

func _world_active() -> bool:
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic): return host.starting_magic.world_active()
	return not host.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if not _world_active() or not is_finite(delta) or delta <= 0: return
	clock = fmod(clock + delta, 3600.0)
	present()
