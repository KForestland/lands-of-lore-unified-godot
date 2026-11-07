extends Node3D
## Huline Jungle generic sprite props (tools/prepare_jungle_props.py): the original unscripted grass, ferns, palms,
## vines and rocks as Y-locked billboards, one MultiMesh per material and bounds group. Scripted props stay with their
## feature hosts. Modern adapters (docs/DEVIATIONS.md): no collision, one shared animation phase per material.
const ROOT := "res://assets/lol2/generated/jungle_props/"
var data: Dictionary = {}
var materials: Dictionary = {}  # material key -> StandardMaterial3D
var frames: Dictionary = {}     # material key -> Array[Texture2D]
var clock := 0.0
var instance_count := 0
var placements: Dictionary = {}  # record -> [MultiMesh, index, base position]

static func assets_ready() -> bool: return FileAccess.file_exists(ROOT + "props.json")

func setup() -> String:
	name = "JungleProps"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "props.json"))
	if not parsed is Dictionary or str(parsed.get("area", "")) != "L4_HJ": return "Jungle props missing or invalid."
	data = parsed
	for key in data.materials:
		var list: Array[Texture2D] = []
		for file in data.materials[key].frames: list.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + file)))
		frames[key] = list
		var m := StandardMaterial3D.new()
		m.albedo_texture = list[0]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		materials[key] = m
	for group in data.groups:
		var quad := QuadMesh.new()
		quad.size = Vector2(float(group.right) - float(group.left), float(group.top) - float(group.bottom))
		quad.center_offset = Vector3((float(group.left) + float(group.right)) / 2.0, (float(group.bottom) + float(group.top)) / 2.0, 0)
		quad.material = materials[group.material]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = quad
		multi.instance_count = group.instances.size()
		for i in group.instances.size():
			var row: Array = group.instances[i]
			multi.set_instance_transform(i, Transform3D(Basis(), Vector3(float(row[0]), float(row[1]), float(row[2]))))
			placements[int(row[3])] = [multi, i, Vector3(float(row[0]), float(row[1]), float(row[2]))]
		var node := MultiMeshInstance3D.new()
		node.name = "%s_%d" % [group.material, get_child_count()]
		node.multimesh = multi
		add_child(node)
		instance_count += group.instances.size()
	return ""

## Lowers or raises one prop with its moving region floor (river dam); dy is relative to its native height.
func settle(record: int, dy: float) -> bool:
	if not placements.has(record): return false
	var p: Array = placements[record]
	p[0].set_instance_transform(p[1], Transform3D(Basis(), p[2] + Vector3.UP * dy))
	return true

func _process(delta: float) -> void:
	clock += delta
	for key in materials:
		var fps := float(data.materials[key].fps)
		var list: Array = frames[key]
		if fps <= 0.0 or list.size() < 2: continue
		materials[key].albedo_texture = list[int(clock * fps) % list.size()]
