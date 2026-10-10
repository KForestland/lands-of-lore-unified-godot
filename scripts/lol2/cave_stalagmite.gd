extends Node3D
## Source one-time Stalagmite pickup; E/range and inventory presentation are modern.
const ROOT := "res://assets/lol2/generated/cave_stalagmite/"
const RECORDS := [144, 145, 146, 147, 148, 149, 641]
var host: Node3D
var plants: Dictionary = {}
var textures: Array[Texture2D] = []
var collected: Array = []

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
		add_child(mesh)
		host._copy_occluders(mesh)
		plants[int(plant.record)] = mesh

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
	for pair in host.occluder_pairs + host.light_pairs:
		if pair[0] == mesh: pair[1].material_override.set_shader_parameter("indices",texture)
