extends Node3D
## Hive (L5_HC) and Huline Jungle (L4_HJ) ambient scenery props the port did not draw before (G58/G71: poles, bumps, smoke
## pits, rocks, statues, steam; the Jungle fog, idol, tall tree, hedge pillars, pot, sack, grass...), from
## hive_jungle_scenery_source.json (tools/prepare_hive_jungle_scenery.py). One area per instance: setup(host, area_id).
## Each row is its native placement, selector-0 box (left/right/bottom/top) and art, batched like jungle_props.gd: one
## MultiMesh per material, box and flip pair, fixed-Y billboards (adapter), alpha scissor, nearest filtering.
## FIRST FRAME ONLY: frame_seconds is null in the contract and this script has no _process, because no Hive or Jungle frame
## rate is proven (G58/G67). Frame flags 0x40/0x80 flip columns/rows (native 129AC8 setup). No collision (blocking UNKNOWN),
## nothing saved. The sound-only owner groups decoded in the contract are not hosted here.
const SOURCE := "res://scripts/lol2/hive_jungle_scenery_source.json"
const ROOT := "res://assets/lol2/generated/hive_jungle_scenery/"
## One staged file per area, so a missing pack leaves the area untouched instead of failing setup.
const PROBE := {"L5_HC": "L5_HC_prop_59_0.png", "L4_HJ": "L4_HJ_prop_162_0.png"}
var host: Node3D
var area := ""
var source: Dictionary
var rows: Dictionary
var textures := {}  # material -> Array[ImageTexture] (every staged frame; only frame 0 is shown)
var materials := {}  # group index -> StandardMaterial3D
var batches: Array[MultiMeshInstance3D] = []
var placements := {}  # record -> [MultiMesh, instance index, position]
var instance_count := 0

static func assets_ready(area_id: String) -> bool:
	return PROBE.has(area_id) and FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + str(PROBE[area_id]))

func setup(walkthrough: Node3D, area_id: String) -> String:
	name = "HiveJungleScenery"
	host = walkthrough
	area = area_id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not parsed is Dictionary or int(parsed.version) != 1 or not parsed.areas.has(area_id): return "Invalid Hive/Jungle scenery source."
	source = parsed
	if source.frame_seconds != null: return "Hive/Jungle scenery has no proven frame rate; frame_seconds must be null."
	var pack: Dictionary = source.areas[area_id]
	rows = pack.rows
	for material in pack.art:
		var frames: Array[ImageTexture] = []
		for f in pack.art[material]:
			if FileAccess.get_sha256(ROOT + str(f)) != str(source.files[f]): return "Hive/Jungle scenery media changed: " + str(f)
			frames.append(ImageTexture.create_from_image(Image.load_from_file(ROOT + str(f))))
		textures[material] = frames
	for group in pack.groups:
		var material := StandardMaterial3D.new()
		material.albedo_texture = textures[group.material][0]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# Native 129AC8 setup: frame flag 0x40 reverses columns, 0x80 reverses rows.
		var flip := int(group.flip)
		material.uv1_scale = Vector3(-1.0 if flip & 0x40 else 1.0, -1.0 if flip & 0x80 else 1.0, 1.0)
		material.uv1_offset = Vector3(1.0 if flip & 0x40 else 0.0, 1.0 if flip & 0x80 else 0.0, 0.0)
		var quad := QuadMesh.new()
		quad.size = Vector2(float(group.right) - float(group.left), float(group.top) - float(group.bottom))
		quad.center_offset = Vector3((float(group.left) + float(group.right)) / 2.0, (float(group.bottom) + float(group.top)) / 2.0, 0.0)
		quad.material = material
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = quad
		multi.instance_count = group.instances.size()
		for i in group.instances.size():
			var row: Array = group.instances[i]
			var at := Vector3(float(row[0]), float(row[1]), float(row[2]))
			multi.set_instance_transform(i, Transform3D(Basis(), at))
			placements[int(row[3])] = [multi, i, at]
		var node := MultiMeshInstance3D.new()
		node.name = "Scenery_%s_%d" % [group.material, batches.size()]
		node.multimesh = multi
		add_child(node)
		materials[batches.size()] = material
		batches.append(node)
		instance_count += group.instances.size()
	return ""

## World position of one hosted record (tests and probes).
func position_of(record: int) -> Vector3:
	return placements[record][2] if placements.has(record) else Vector3.INF
