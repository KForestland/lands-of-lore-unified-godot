extends Node3D
## Source one-time Stalagmite pickup; E/range and inventory presentation are modern.
const ROOT := "res://assets/lol2/generated/cave_stalagmite/"
const RECORDS := [144, 145, 146, 147, 148, 149, 641]
var host: Node3D
var plants: Dictionary = {}
var textures: Array[Texture2D] = []
var collected: Array = []
var glow := preload("res://scripts/lol2/cave_crystal_glow.gd").new()

## Original F1EB8 follows state byte11 bit0: selector0 draws122 then123 at the same height.
## Both ordinary layers have identical bounds and index0 transparency; compose once, preserving one world draw.
## Selector2/4 frame-flag0x10 effects are separate from this ordinary shard layer.
static func ordinary_layers(base: Image, shard: Image) -> Image:
	assert(base.get_size() == shard.get_size())
	var result := base.duplicate() as Image
	for y in shard.get_height():
		for x in shard.get_width():
			var pixel := shard.get_pixel(x, y)
			if pixel.r > 0.0: result.set_pixel(x, y, pixel)
	return result


static func item_id(record: int, harvest: int) -> String:
	return "cave:prop%d:harvest%d:Stalagmite" % [record, harvest]

static func valid_item(id: Variant) -> bool:
	if not id is String: return false
	for record in RECORDS:
		for harvest in range(1,2):
			if id == item_id(record, harvest): return true
	return false

static func validate_ids(ids: Variant) -> bool:
	if not ids is Array or ids.size() > 7: return false
	var seen: Array = []
	for id in ids:
		if not valid_item(id) or id in seen: return false
		seen.append(id)
	return true

func setup(walkthrough: Node3D) -> void:
	host = walkthrough
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"stalagmite.json"))
	for state in source.states:
		assert(FileAccess.get_sha256(ROOT+state.image) == state.sha256)
		textures.append(ImageTexture.create_from_image(Image.load_from_file(ROOT+state.image)))
	var base := Image.load_from_file(ROOT+str(source.states[0].image))
	var shard := Image.load_from_file(ROOT+str(source.states[1].image))
	# Keep selector3's original122 texture unchanged for harvested/legacy saves.
	textures[0] = ImageTexture.create_from_image(ordinary_layers(base, shard))
	for plant in source.plants:
		var mesh := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var state: Dictionary = source.states[0]
		quad.size = Vector2(state.right-state.left,state.top-state.bottom)
		quad.center_offset = Vector3((state.left+state.right)/2.0,(state.top+state.bottom)/2.0,0)
		mesh.mesh = quad
		mesh.position = host.point(plant.position)+host.native_translation
		mesh.layers = 2
		mesh.set_meta("original_record",int(plant.record))
		mesh.material_override = host._indexed_material(ROOT+state.image)
		mesh.material_override.set_shader_parameter("sprite",true)
		mesh.material_override.set_shader_parameter("indices",textures[0])
		add_child(mesh)
		host._copy_occluders(mesh)
		plants[int(plant.record)] = mesh
	glow.setup(host, self, source)

func count_for(record: int) -> int:
	var count := 0
	for harvest in range(1,2):
		if item_id(record,harvest) in collected: count += 1
	return count

func target() -> int:
	if host.flying or host.get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return -1
	var best := -1
	var distance := 96.0
	for record in RECORDS:
		if count_for(record) >= 1: continue
		var mesh: MeshInstance3D = plants[record]
		var position := mesh.to_global(mesh.mesh.center_offset)
		var delta: Vector3 = position-host.camera.global_position
		if delta.length() < 0.01 or delta.length() > distance: continue
		if (-host.camera.global_basis.z).dot(delta.normalized()) < 0.97: continue
		var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position,position,1,[host.player.get_rid()])
		ray.hit_from_inside = true
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		best = record
		distance = delta.length()
	return best

func harvest() -> bool:
	var record := target()
	if record < 0: return false
	collected.append(item_id(record,count_for(record)+1))
	_sync(record)
	return true

func restore(ids: Array) -> void:
	assert(validate_ids(ids))
	collected = ids.duplicate()
	for record in RECORDS: _sync(record)

func _sync(record: int) -> void:
	var mesh: MeshInstance3D = plants[record]
	var texture: Texture2D = textures[3 if count_for(record) > 0 else 0]
	mesh.material_override.set_shader_parameter("indices",texture)
	glow.restore(record, count_for(record) > 0)
	if host.has_method("sync_render_source"):
		host.sync_render_source(mesh, texture)
