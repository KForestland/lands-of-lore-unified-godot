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
var stone: MeshInstance3D
var foil_marker: MeshInstance3D
var stone_size := Vector2.ZERO
## Layer-2 meshes mirrored into the cave's mask pass (host.occluder_pairs).
var mirrored: Array = []
var box: Node3D
var foil_base := Vector3.ZERO

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

## An indexed billboard quad on the cave's layer-2 index viewport (the cave Aloe/stalagmite convention): the image
## holds palette indices; index0 is transparent. Mirrored into the mask pass like the cave's own sprites.
func _indexed_sprite(path: String, position: Vector3, width: float) -> MeshInstance3D:
	var image := Image.load_from_file(path)
	var quad := QuadMesh.new()
	var height: float = width * float(image.get_height()) / float(image.get_width())
	quad.size = Vector2(width, height)
	quad.center_offset = Vector3(0, height / 2.0, 0)
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.layers = 2
	mesh.material_override = host._indexed_material(path)
	mesh.material_override.set_shader_parameter("sprite", true)
	mesh.position = position
	add_child(mesh)
	_mirror(mesh)
	return mesh

func _mirror(mesh: MeshInstance3D) -> void:
	var before: int = host.occluder_pairs.size()
	host._copy_occluders(mesh)
	if host.occluder_pairs.size() > before: mirrored.append(host.occluder_pairs.back())

func _sync_mirrors() -> void:
	for pair in mirrored:
		if is_instance_valid(pair[0]) and is_instance_valid(pair[1]):
			pair[1].global_transform = pair[0].global_transform
			pair[1].visible = pair[0].is_visible_in_tree()

func setup(walkthrough: Node3D) -> void:
	name = "CaveStoneManafoil"
	host = walkthrough
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var offset: Vector3 = host.native_translation
	var st: Dictionary = source.stone
	stone = _indexed_sprite(ROOT + "stone_index.png", host.point(st.position) + offset, float(st.sprite.right) - float(st.sprite.left))
	stone_size = (stone.mesh as QuadMesh).size
	# Box faces: the cave's indexed wall surface for resource86 (wall_indices/material_86.png).
	var mat: Material = host._indexed_material(host.INDEX_ROOT + "material_86.png")
	box = Node3D.new(); add_child(box)
	var top := -INF
	for face in source.foil.faces:
		var stool := SurfaceTool.new(); stool.begin(Mesh.PRIMITIVE_TRIANGLES); stool.set_material(mat)
		for index in [0,1,2,0,2,3]:
			var p: Array = face.points[index]
			stool.set_uv(Vector2(face.uv[index][0], face.uv[index][1])); stool.add_vertex(Vector3(p[0], p[1], p[2]) + offset)
			top = maxf(top, float(p[1]))
		stool.generate_normals()
		var mesh := MeshInstance3D.new(); mesh.mesh = stool.commit(); mesh.layers = 2; box.add_child(mesh); _mirror(mesh)
	var fp: Array = source.foil.position
	foil_marker = _indexed_sprite(ROOT + "foil_index.png", Vector3(float(fp[0]), top, float(fp[2])) + offset, 24.0)
	foil_base = foil_marker.position
	restore([])

## control75 stands on shaft region506; it rides that floor when prop83's chain lifts it (cave_prop83_lift.gd).
func set_lift(offset: float) -> void:
	box.position.y = offset
	foil_marker.position = foil_base + Vector3.UP * offset
	_sync_mirrors()

func restore(ids: Variant) -> void:
	collected = (ids as Array).duplicate() if validate_ids(ids) else []
	stone.visible = not STONE in collected
	foil_marker.visible = not FOIL in collected
	_sync_mirrors()

func aim_point(id: String) -> Vector3:
	if id == STONE: return stone.global_position + Vector3.UP * (stone_size.y * 0.5)
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
