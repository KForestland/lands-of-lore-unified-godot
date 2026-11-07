extends Node3D
## Generic renderer for one map's original static assemblies (tools/prepare_static_assemblies.py).
## Assemblies owned by feature hosts are excluded by the producer (scripts/lol2/static_assembly_owners.json).
## Initial-mode faces are batched into one mesh per material; assemblies with other-mode faces get their own meshes so a
## host can call set_mode(). No collision. Indexed areas (Cave) use the host's indexed surface material on layer 2 plus
## its occluder/lighting copies; colour areas (Museum) use unshaded RGBA materials.
const ROOT := "res://assets/lol2/generated/static_assemblies/"
var host: Node3D
var data: Dictionary = {}
var materials: Dictionary = {}
var stateful_meshes: Dictionary = {}  # assembly -> Array[MeshInstance3D]
var modes: Dictionary = {}            # assembly -> mode set by a host (absent = initial)
## Presence of the assemblies a host manages (setup `presence`): placement flags word +8 bit 0x1000 marks an assembly
## absent at load; source op9 property3 links it and property2 unlinks it. Managed assemblies get their own meshes and
## follow set_present() in drawing and in any solid body; unmanaged ones stay drawn as before.
const ABSENT_FLAG := 0x1000
var presence: Dictionary = {}         # managed assembly -> present

static func assets_ready(area: String) -> bool:
	return FileAccess.file_exists(ROOT + area + "/assemblies.json")

## `separate`: assemblies a host moves (set_offset); they get their own meshes like stateful ones.
## `own_collision`: drawn assemblies whose host builds its own collider (also implied for `separate`).
## `managed_presence`: assemblies whose link state a host drives (set_present); they start in their source presence.
## `draw_faces` false: the pack draws unmanaged assembly faces. Managed presence still builds its own meshes here, and the
## pack leaves those faces out so they are not drawn twice.
func setup(owner_host: Node3D, area: String, separate: Array = [], own_collision: Array = [], managed_presence: Array = [], draw_faces: bool = true) -> String:
	host = owner_host
	name = "StaticAssemblies_" + area
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + area + "/assemblies.json"))
	if not parsed is Dictionary or str(parsed.get("area", "")) != area: return "Static assemblies for %s missing or invalid." % area
	data = parsed
	var stateful: Dictionary = {}
	for id in data.stateful: stateful[int(id)] = true
	for id in separate: stateful[int(id)] = true
	for id in managed_presence:
		if not data.placements.has(str(int(id))): return "Assembly %s has no placement in %s." % [id, area]
		stateful[int(id)] = true
		presence[int(id)] = initially_present(data, int(id))
	var batched: Dictionary = {}
	var own: Dictionary = {}
	for face in data.faces:
		if not face.initial: continue
		var id := int(face.assembly)
		if stateful.has(id):
			if not own.has(id): own[id] = []
			own[id].append(face)
		else:
			if not batched.has(face.material): batched[face.material] = []
			batched[face.material].append(face)
	if draw_faces:
		for key in batched: _add(_mesh(batched[key], key), "Batch_" + str(key).get_basename())
		for id in own: _build_assembly(id, own[id])
	else:
		for id in presence:
			if own.has(int(id)): _build_assembly(int(id), own[int(id)])
	return _build_collision(area, separate + own_collision)

## Native solid boxes (tools/prepare_static_collision.py): placement word8 bit 0x80 plus a box template shape. Only
## assemblies this renderer draws; host-owned ones and `skip` build their own. Modern adapter: boxes lower than
## MIN_SOLID_HEIGHT stay walkable (the original steps over them; a Godot body cannot).
const MIN_SOLID_HEIGHT := 16
## Thin source-solid decks raised over a gap stay solid: a walkable footprint (both sides >= 48) whose base is higher
## above the floor under its centre than the tallest player form (beast, 69), so no walk beneath it can be obstructed.
## Measured by tests/static_raised_decks_test.gd: only Jungle deck 227 over the stream (owner r12h F10 2026-10-26: fell
## through it). L9 Noble balcony481..483 likewise stand112 above floor0; their source tops join the upstairs floor120.
## Lower thin decks (221-224, 219: 20-25 above the stream bed) keep the walkable adapter.
const RAISED_DECKS := {"L4_HJ": [227], "L9_DR": [481,482,483]}
static func raised_deck(area: String, id: int) -> bool: return id in RAISED_DECKS.get(area, [])
## Scenery boxes use their own layer (9): bodies that move (player, creatures) add it to their masks, while the many
## aim/line-of-sight ray queries on layer 1 keep ignoring them (a post beside the cave chain must not hide it).
const SCENERY_LAYER := 1 << 8
var solid_bodies: Dictionary = {}  # assembly -> StaticBody3D
func _build_collision(area: String, skip: Array) -> String:
	var path := "res://scripts/lol2/static_collision_%s.json" % area
	if not FileAccess.file_exists(path): return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or str(parsed.get("area", "")) != area: return "Static collision for %s invalid." % area
	var offset: Vector3 = host.native_translation if str(data.render) == "indexed" else Vector3.ZERO
	var drawn: Dictionary = {}
	for face in data.faces: drawn[int(face.assembly)] = true
	for key in parsed.boxes:
		var id := int(key)
		var b: Dictionary = parsed.boxes[key]
		# Scripted assemblies move or unlink at run time: their hosts own any collision.
		var deck := raised_deck(area, id)
		if not drawn.has(id) or id in skip or bool(b.get("scripted", false)) or (int(b.height) < MIN_SOLID_HEIGHT and not deck): continue
		var body := box_body(id, b, offset, deck)
		if body == null: continue
		add_child(body)
		solid_bodies[id] = body
		_present_body(id)
	if not solid_bodies.is_empty() and host.get("player") is CollisionObject3D: host.player.collision_mask |= SCENERY_LAYER
	return ""

## Scripted solids a host keeps standing in their placed state (their run-time events are not hosted yet).
func add_scripted_solids(area: String, ids: Array) -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_%s.json" % area))
	if not parsed is Dictionary or str(parsed.get("area", "")) != area: return "Static collision for %s invalid." % area
	var offset: Vector3 = host.native_translation if str(data.render) == "indexed" else Vector3.ZERO
	for id in ids:
		var b: Variant = parsed.boxes.get(str(id))
		if not b is Dictionary or not bool(b.get("scripted", false)) or solid_bodies.has(int(id)): return "Assembly %s is not a scripted solid." % id
		var body := box_body(int(id), b, offset)
		if body == null: return "Assembly %s has no solid box." % id
		add_child(body)
		solid_bodies[int(id)] = body
		_present_body(int(id))
	if host.get("player") is CollisionObject3D: host.player.collision_mask |= SCENERY_LAYER
	return ""

## Source presence at load: placement flags word (+8) bit 0x1000 clear.
static func initially_present(source: Dictionary, id: int) -> bool:
	var raw: String = str(source.placements[str(id)].placement_hex)
	return (raw.hex_decode().decode_u16(8) & ABSENT_FLAG) == 0

## op9 property3 (true) / property2 (false) on a managed assembly: its meshes and any solid body follow.
func set_present(id: int, present: bool) -> void:
	if not presence.has(id): return push_error("Assembly %d presence is not managed." % id)
	presence[id] = present
	for mesh in stateful_meshes.get(id, []): mesh.visible = present
	_present_body(id)

func is_present(id: int) -> bool: return bool(presence.get(id, true))

func _present_body(id: int) -> void:
	if not presence.has(id) or not solid_bodies.has(id): return
	var body: StaticBody3D = solid_bodies[id]
	body.collision_layer = SCENERY_LAYER if presence[id] else 0
	body.process_mode = Node.PROCESS_MODE_INHERIT if presence[id] else Node.PROCESS_MODE_DISABLED

## Saved presence of the managed assemblies ({"id": bool}); restore_presence() takes it back.
func presence_state() -> Dictionary:
	var saved := {}
	for id in presence: saved[str(id)] = presence[id]
	return saved

static func validate_presence(saved: Variant, managed: Array) -> String:
	if not saved is Dictionary or saved.size() != managed.size(): return "Invalid assembly presence."
	for id in managed:
		if not saved.get(str(int(id))) is bool: return "Invalid assembly presence."
	return ""

func restore_presence(saved: Dictionary) -> String:
	var error := validate_presence(saved, presence.keys())
	if not error.is_empty(): return error
	for id in presence.keys(): set_present(id, bool(saved[str(id)]))
	return ""

## One static_collision_AREA.json box record as a body on SCENERY_LAYER (null when nothing is solid enough). Also used
## by hosts that draw the assemblies themselves (dark_halls.gd).
static func box_body(id: int, b: Dictionary, offset: Vector3, deck: bool = false) -> StaticBody3D:
	if int(b.get("mode", 2)) == 3: return _child_box_body(id, b, offset, deck)
	var body := StaticBody3D.new()
	body.name = "Solid%d" % id
	body.collision_layer = SCENERY_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(b.width), float(b.height), maxf(float(b.depth), 1.0))
	shape.shape = box
	body.add_child(shape)
	# Native y -> Godot -z; heading H turns the width axis to map angle H, i.e. Godot Y rotation -H.
	body.position = Vector3(float(b.x), float(b.h) + float(b.height) / 2.0, -float(b.y)) + offset
	body.rotation.y = -float(b.heading) / 65536.0 * TAU
	return body

## Mode 3 (template byte 0x2D&3 == 3): 5BD90 -> 5C1F5/5C3B6 -> 5BFEC tests each child record (stride 0x3C) as its own
## box, so a frame such as the Museum archways (template 4) keeps its walk-through opening. Each child admitted by its
## mask bit for the initial assembly mode 0 becomes a box from its record bounds (signed x/y bytes 0x34..0x37, height
## bytes 0x38/0x39 above the placement), in the same heading frame as whole boxes; type 1 children (not drawn by the
## exporter, e.g. Cave table 156 child 12) included (Codex OPUS_CAVE156_CHILD_COLLISION). Children whose top is under
## MIN_SOLID_HEIGHT stay walkable, as for whole boxes.
static func _child_box_body(id: int, b: Dictionary, offset: Vector3, deck: bool = false) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Solid%d" % id
	body.collision_layer = SCENERY_LAYER
	body.collision_mask = 0
	for c in b.get("children", []):
		var r: Array = c.bounds
		if (int(c.mask) & 1) == 0 or (int(r[5]) < MIN_SOLID_HEIGHT and not deck): continue
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(maxf(float(r[1]) - float(r[0]), 1.0), maxf(float(r[5]) - float(r[4]), 1.0), maxf(float(r[3]) - float(r[2]), 1.0))
		shape.shape = box
		# Native local y -> body-local -z (the frame of the whole boxes above).
		shape.position = Vector3((float(r[0]) + float(r[1])) / 2.0, (float(r[4]) + float(r[5])) / 2.0, -(float(r[2]) + float(r[3])) / 2.0)
		body.add_child(shape)
	if body.get_child_count() == 0:
		body.free()
		return null
	body.position = Vector3(float(b.x), float(b.h), -float(b.y)) + offset
	body.rotation.y = -float(b.heading) / 65536.0 * TAU
	return body

## Select faces by child mask (renderer test mask & (1 << mode)), as the original assembly mode byte does.
func set_mode(assembly: int, mode: int) -> void:
	if not stateful_meshes.has(assembly): return
	modes[assembly] = mode
	var faces: Array = []
	for face in data.faces:
		if int(face.assembly) == assembly and (int(face.mask) & (1 << mode)) != 0: faces.append(face)
	for mesh in stateful_meshes[assembly]:
		for bank in ["occluder_by_source", "light_by_source"]:
			var copies: Variant = host.get(bank)
			if copies is Dictionary and (copies as Dictionary).has(mesh):
				(copies as Dictionary)[mesh].queue_free()
				(copies as Dictionary).erase(mesh)
		mesh.queue_free()
	stateful_meshes.erase(assembly)
	_build_assembly(assembly, faces)

## Move a separately built assembly (and its occluder/lighting copies) by `offset` from its placement.
func set_offset(assembly: int, offset: Vector3) -> void:
	for mesh in stateful_meshes.get(assembly, []):
		mesh.position = offset
		for bank in ["occluder_by_source", "light_by_source"]:
			var copies: Variant = host.get(bank)
			if copies is Dictionary and (copies as Dictionary).has(mesh): (copies as Dictionary)[mesh].global_transform = mesh.global_transform

func drawn_face_count() -> int:
	var count := 0
	for child in get_children():
		if child is MeshInstance3D and child.layers != 4 and child.mesh != null: count += child.mesh.get_faces().size() / 6
	return count

func _build_assembly(id: int, faces: Array) -> void:
	var by_material: Dictionary = {}
	for face in faces:
		if not by_material.has(face.material): by_material[face.material] = []
		by_material[face.material].append(face)
	stateful_meshes[id] = []
	for key in by_material:
		var mesh := _mesh(by_material[key], key)
		_add(mesh, "Assembly%d_%s" % [id, str(key).get_basename()])
		mesh.visible = bool(presence.get(id, true))
		stateful_meshes[id].append(mesh)

func _material(key: String) -> Material:
	if materials.has(key): return materials[key]
	var row: Dictionary = data.materials[key]
	var path: String = ROOT + str(data.area) + "/" + key
	var material: Material
	if str(data.render) == "indexed":
		var indexed: ShaderMaterial = host._indexed_material(path)
		indexed.set_shader_parameter("cutout", bool(row.cutout))
		_shadow_decal(indexed, key)
		material = indexed
	else:
		var colour := StandardMaterial3D.new()
		colour.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(path))
		colour.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		colour.cull_mode = BaseMaterial3D.CULL_DISABLED
		colour.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		if bool(row.cutout): colour.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material = colour
	materials[key] = material
	return material

func _mesh(faces: Array, key: String) -> MeshInstance3D:
	var offset: Vector3 = host.native_translation if str(data.render) == "indexed" else Vector3.ZERO
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		for i in [0, 1, 2, 0, 2, 3]:
			surface.set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
			surface.add_vertex(Vector3(face.points[i][0], face.points[i][1], face.points[i][2]) + offset)
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = _material(key)
	if str(data.render) == "indexed": mesh.layers = 2
	return mesh

func _add(mesh: MeshInstance3D, label: String) -> void:
	mesh.name = label
	add_child(mesh)
	if str(data.render) == "indexed" and host.has_method("_copy_occluders"): host._copy_occluders(mesh)

## Index 1 is the original's shadow marker (palette entry 1 is pure green); the native renderer darkens with it.
## Modern stand-in (docs/DEVIATIONS.md): draw it as black index 3. Material 944 (template23 scratched route arrows)
## is mirrored: owner 2026-10-21 18:26 "should be black and facing the other way, -> not <-".
const SHADOW_INDEX := 1
const BLACK_INDEX := 3
const MIRRORED := ["material_0944.png"]
func _shadow_decal(material: ShaderMaterial, key: String) -> void:
	var texture: Texture2D = material.get_shader_parameter("indices")
	if texture == null: return
	var image: Image = texture.get_image()
	var changed := false
	for y in image.get_height():
		for x in image.get_width():
			if int(round(image.get_pixel(x, y).r * 255.0)) == SHADOW_INDEX:
				image.set_pixel(x, y, Color(BLACK_INDEX / 255.0, 0, 0)); changed = true
	if key in MIRRORED: image.flip_x(); changed = true
	if changed: material.set_shader_parameter("indices", ImageTexture.create_from_image(image))
