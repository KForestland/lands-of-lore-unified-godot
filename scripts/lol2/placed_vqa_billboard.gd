extends Node3D
## Prop 78 on L19 and prop 242 on L20 are external 0x342 videos.
## L19_BCI index 5 is SPHERE3\L19_BC\E224E.VQA (228x348, 1256 frames).
## L20_BBI index 24 is SPHERE3\L20_BB\PLACENTA.VQA (640x340, 60 frames).
## bb_brth.vqa is L20_BBI index 25 and is a different reel. This host does not play it.
## hw01.vqa is a cstring in L17_HC.MIX and has no movie-MIX entry.
## The 0x342 enable was not entered. Each quad plays when its map loads and repeats.
## A native loop bit was not read. Ogg on the recorded corners is the presentation.
const E224E_SHA := "2a4c3fa6163cf4ac5f6ddb38fa1777548a4d93b4ca6292036bf4a5db020b7363"
const PLACENTA_SHA := "e5605c7362bbbed3bf29792608cb313f9979f2cf364540c3cba315c25d6da6da"
const E224E_MEDIA := "res://assets/lol2/generated/l19_e224e/movie.json"
const PLACENTA_MEDIA := "res://assets/lol2/generated/l20_placenta/movie.json"
const HIT_LAYER := 1 << 20
var media: Dictionary = {}
var corners := PackedVector3Array()
var video: VideoStreamPlayer
var quad: MeshInstance3D

static func dawn_corners() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(2744.5, -1000, -882),
		Vector3(2859.5, -1000, -882),
		Vector3(2859.5, -929, -882),
		Vector3(2744.5, -929, -882),
	])

static func placenta_corners() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(-1235, -20, -4258),
		Vector3(-1085, -20, -4258),
		Vector3(-1085, 80, -4258),
		Vector3(-1235, 80, -4258),
	])

static func stand_at(points: PackedVector3Array) -> Vector3:
	var center := (points[0] + points[1] + points[2] + points[3]) * 0.25
	var bottom := minf(points[0].y, points[2].y)
	return Vector3(center.x, bottom + 32.0, center.z + 40.0)

static func media_row(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		return {}
	var row: Dictionary = data
	if not FileAccess.file_exists(str(row.get("path", ""))):
		return {}
	return row

static func attach_dawn(map: Node3D) -> Node:
	return _attach(map, "L19E224e", E224E_MEDIA, dawn_corners())

static func attach_placenta(map: Node3D) -> Node:
	return _attach(map, "L20Placenta", PLACENTA_MEDIA, placenta_corners())

static func _attach(map: Node3D, node_name: String, path: String, points: PackedVector3Array) -> Node:
	var row := media_row(path)
	if row.is_empty():
		return null
	var n: Node3D = load("res://scripts/lol2/placed_vqa_billboard.gd").new()
	n.name = node_name
	n.set("media", row)
	n.set("corners", points)
	map.add_child(n)
	return n

func _ready() -> void:
	if media.is_empty() or corners.size() != 4:
		return
	var width := absf(corners[1].x - corners[0].x)
	var height := absf(corners[2].y - corners[1].y)
	var center := (corners[0] + corners[1] + corners[2] + corners[3]) * 0.25
	var vp := SubViewport.new()
	vp.name = "Viewport"
	vp.size = Vector2i(int(media.width), int(media.height))
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	video = VideoStreamPlayer.new()
	video.name = "Reel"
	video.set_anchors_preset(Control.PRESET_FULL_RECT)
	video.expand = true
	var stream := VideoStreamTheora.new()
	stream.file = str(media.path)
	video.stream = stream
	video.finished.connect(_repeat)
	vp.add_child(video)
	video.play()
	quad = MeshInstance3D.new()
	quad.name = "Quad"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, height)
	quad.mesh = mesh
	quad.position = center
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = vp.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = Vector3(1, -1, 1)
	mat.uv1_offset = Vector3(0, 1, 0)
	quad.material_override = mat
	add_child(quad)
	var body := StaticBody3D.new()
	body.name = "Hit"
	body.collision_layer = HIT_LAYER
	body.collision_mask = 0
	body.position = center
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.4)
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _repeat() -> void:
	if video != null:
		video.play()
