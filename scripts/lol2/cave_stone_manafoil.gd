extends Node3D
## Cave Ancient Stone (prop1050) and Mana foil (control75) pickups (cave_stone_manafoil_source.json).
## Saved by the cave host as "stone_manafoil" = the collected ids (each item can be taken once; history is kept, and
## the host's carried list filters consumed ids). E with the pickup aimed and in reach:
##  - prop1050 kind4 mode0 at state0: one "66-Ancients stn", the stone leaves the world (op9 property16).
##  - control75: group9750 runs when local16 is 0 (help screen not hosted), then the selector advances to 1 (modern
##    adapter: no selector writer found in the audited scope) and the source kind3 group9768 grants one "131-Mana foil".
const STONE := "cave:prop1050:Ancients_Stone"
const FOIL := "cave:control75:Mana_foil"
const SOURCE := "res://scripts/lol2/cave_stone_manafoil_source.json"
const ROOT := "res://assets/lol2/generated/cave_stone_manafoil/"
const REACH := 96.0
var host: Node3D
var source: Dictionary
var collected: Array = []
var stone: Sprite3D
var foil_marker: Sprite3D
var box: Node3D

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "stone.png") and FileAccess.file_exists(ROOT + "foil_icon.png") and FileAccess.file_exists(ROOT + "m0086.png")
static func valid_item(id: Variant) -> bool: return id is String and id in [STONE, FOIL]
static func validate_ids(ids: Variant) -> bool:
	if not ids is Array or ids.size() > 2: return false
	var seen: Array = []
	for id in ids:
		if not valid_item(id) or id in seen: return false
		seen.append(id)
	return true

func _sprite(path: String, position: Vector3, width: float) -> Sprite3D:
	var image := Image.load_from_file(path)
	var s := Sprite3D.new()
	s.texture = ImageTexture.create_from_image(image)
	s.pixel_size = width / float(image.get_width())
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.offset.y = image.get_height() / 2.0
	s.position = position
	add_child(s)
	return s

func setup(walkthrough: Node3D) -> void:
	name = "CaveStoneManafoil"
	host = walkthrough
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var offset: Vector3 = host.native_translation
	var st: Dictionary = source.stone
	stone = _sprite(ROOT + "stone.png", host.point(st.position) + offset, float(st.sprite.right) - float(st.sprite.left))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT + str(source.foil.box_material)))
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	box = Node3D.new(); add_child(box)
	var top := -INF
	for face in source.foil.faces:
		var stool := SurfaceTool.new(); stool.begin(Mesh.PRIMITIVE_TRIANGLES); stool.set_material(mat)
		for index in [0,1,2,0,2,3]:
			var p: Array = face.points[index]
			stool.set_uv(Vector2(face.uv[index][0], face.uv[index][1])); stool.add_vertex(Vector3(p[0], p[1], p[2]) + offset)
			top = maxf(top, float(p[1]))
		stool.generate_normals()
		var mesh := MeshInstance3D.new(); mesh.mesh = stool.commit(); box.add_child(mesh)
	var fp: Array = source.foil.position
	foil_marker = _sprite(ROOT + "foil_icon.png", Vector3(float(fp[0]), top, float(fp[2])) + offset, 24.0)
	restore([])

func restore(ids: Variant) -> void:
	collected = (ids as Array).duplicate() if validate_ids(ids) else []
	stone.visible = not STONE in collected
	foil_marker.visible = not FOIL in collected

func aim_point(id: String) -> Vector3:
	if id == STONE: return stone.global_position + Vector3.UP * (stone.texture.get_height() * stone.pixel_size * 0.5)
	return foil_marker.global_position + Vector3.UP * 4.0

func target() -> String:
	if host.flying or host.get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return ""
	for id in [STONE, FOIL]:
		if id in collected: continue
		var point := aim_point(id)
		var delta: Vector3 = point - host.camera.global_position
		if delta.length() < 0.01 or delta.length() > REACH or (-host.camera.global_basis.z).dot(delta.normalized()) < 0.95: continue
		var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position, point, 1, [host.player.get_rid()])
		ray.hit_from_inside = true
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return id
	return ""

func prompt() -> String:
	var id := target()
	return "" if id.is_empty() else ("E · Take Ancients' Stone" if id == STONE else "E · Take Mana Foil")

## Returns the granted id, or "" (nothing aimed, already taken, or carrying is full).
func take() -> String:
	var id := target()
	if id.is_empty() or host.carried_items().size() >= preload("res://scripts/lol2/item_catalog.gd").MAX_CARRIED: return ""
	collected.append(id)
	restore(collected)
	return id
