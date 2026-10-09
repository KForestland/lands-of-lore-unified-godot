extends Node3D
## Live Cave owner for the prop83 chain (cave_prop83_lift_state.gd). Producers: an armed melee strike aimed at prop83
## (kind9 g108, context 2/4) and a Spark ray hitting it (g124). The staged sound 956 plays; at its end the chain opens
## the wall regions 1029..1033 and lifts the eight shaft floors. Shaft floors are prisms over the source floor
## polygons with collision; a player standing on one is carried. The opening replaces the solid wall block's vertical
## faces (render and collision) by a floor at -192 and walls on the block's open (no-neighbour) edges.
const State = preload("res://scripts/lol2/cave_prop83_lift_state.gd")
const SOURCE := "res://scripts/lol2/cave_prop83_lift_source.json"
const AUDIO := "res://assets/lol2/generated/cave_prop83_lift/956.wav"
const REACH := 96.0
var host: Node3D
var source: Dictionary
var state: Dictionary = State.initial()
var body: StaticBody3D
var sound: AudioStreamPlayer
var blocks := {}
var opened_applied := false
## Original host meshes/shapes replaced by the opening, restored when a save from before the chain is loaded.
var opening_backup: Array = []
var opened_body: StaticBody3D
var prop_instance: Node3D
var sound_seconds := 0.557
var sprite: MeshInstance3D
var frames: Array[ImageTexture] = []
var frame_index := -1
var frame_clock := 0.0
## Meshes of this owner that the cave's layered renderer mirrors into its mask pass (host.occluder_pairs).
var mirrored: Array = []
## The opened passage's mirror pairs, unregistered from the host when a pre-chain save rewinds the opening.
var passage_pairs: Array = []

static func assets_ready() -> bool: return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(AUDIO)
func checkpoint() -> Dictionary: return state.duplicate(true)

func setup(walkthrough: Node3D) -> void:
	name = "CaveProp83Lift"
	host = walkthrough
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	sound_seconds = float(source.sound.seconds)
	# Prop83 (template92, an animated water jet) is not in the recovered prop preview: drawn here on the cave's visible
	# layer 2 from its exported frames.
	# Indexed billboard quad (palette indices, index0 transparent) like the cave's own sprites; frames swap the indices.
	var root_path := "res://assets/lol2/generated/cave_prop83_lift/"
	for f in source.sprite.index_frames: frames.append(ImageTexture.create_from_image(Image.load_from_file(root_path + str(f))))
	var width: float = float(source.sprite.right) - float(source.sprite.left)
	var height: float = width * float(frames[0].get_height()) / float(frames[0].get_width())
	var quad := QuadMesh.new(); quad.size = Vector2(width, height); quad.center_offset = Vector3(0, height / 2.0, 0)
	sprite = MeshInstance3D.new(); sprite.mesh = quad; sprite.layers = 2
	sprite.material_override = host._indexed_material(root_path + str(source.sprite.index_frames[0]))
	sprite.material_override.set_shader_parameter("sprite", true)
	sprite.position = host.point(source.position) + host.native_translation
	add_child(sprite)
	_mirror(sprite)
	prop_instance = sprite
	body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("spark_receiver", self)
	var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(40, 64, 40); shape.shape = box
	body.add_child(shape)
	body.position = host.point(source.position) + host.native_translation + Vector3(0, 32, 0)
	add_child(body)
	sound = AudioStreamPlayer.new(); sound.stream = AudioStreamWAV.load_from_file(AUDIO); add_child(sound)
	# Each shaft floor is one prism built at its final extent (top at -290, reaching 710 below -1000) and slid
	# vertically: the top follows the current floor height. Top: the region's indexed floor surface; sides: rock.
	var t: Vector3 = host.native_translation
	var low: float = State.SHAFT_START - (State.SHAFT_TOP - State.SHAFT_START) + t.y
	var high: float = State.SHAFT_TOP + t.y
	for key in ["397","434","436","451","452","503","505","506"]:
		var b := StaticBody3D.new(); b.name = "ShaftFloor_" + key
		add_child(b)
		var parts := _prism_parts(_polygon(key), low, high)
		var top := MeshInstance3D.new(); top.mesh = parts.top; top.material_override = _surface_material(int(key)); top.layers = 2; b.add_child(top)
		var side := MeshInstance3D.new(); side.mesh = parts.sides; side.material_override = _rock_material(); side.layers = 2; b.add_child(side)
		var col := CollisionShape3D.new(); var convex := ConvexPolygonShape3D.new(); convex.points = parts.hull; col.shape = convex; b.add_child(col)
		_mirror(top); _mirror(side)
		blocks[key] = {"body":b,"shape":col}
	restore(null)

func restore(saved: Variant) -> String:
	var value = State.initial() if saved == null else saved
	var error := State.validate(value, sound_seconds)
	if not error.is_empty(): return error
	state = State.canonical(value)
	_sync_sound()
	present()
	return ""

## Sound 956 follows the saved remainder: a mid-sound load resumes the clip at (length - remaining).
func _sync_sound() -> void:
	if float(state.sound) > 0.0:
		sound.play(maxf(sound_seconds - float(state.sound), 0.0))
		sound.stream_paused = not _world_active()
	else:
		sound.stop()

## The shared player world gate (inventory/cursor, death, movies, other scene, pause, flying).
func _world_active() -> bool:
	if host.get("starting_magic") != null and is_instance_valid(host.starting_magic): return host.starting_magic.world_active()
	return not host.get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

## Region floor polygon in the host frame, from the source region record.
func _polygon(region: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	var t: Vector3 = host.native_translation
	for p in source.regions[region].polygon: out.append(Vector2(float(p[0]) + t.x, float(p[1]) + t.z))
	return out

## The cave's indexed floor surface of a region (as the static floors use), or a plain fallback.
func _surface_material(region: int) -> Material:
	for face in host.data.faces:
		if int(face.region) != region: continue
		var path: String = host.SURFACE_ROOT + "floor_%s.png" % str(face.material)
		if host.has_method("_indexed_material") and FileAccess.file_exists(path): return host._indexed_material(path)
	return _floor_material(region)
func _rock_material() -> Material:
	return _floor_material(-1)
## Registers a layer-2 mesh with the cave's mask pass (a ShaderMaterial is required there).
func _mirror(mesh: MeshInstance3D) -> Array:
	if host.has_method("_copy_occluders") and mesh.material_override is ShaderMaterial:
		var before: int = host.occluder_pairs.size()
		host._copy_occluders(mesh)
		if host.occluder_pairs.size() > before:
			mirrored.append(host.occluder_pairs.back())
			return host.occluder_pairs.back()
	return []
func _sync_mirrors() -> void:
	for pair in mirrored:
		if is_instance_valid(pair[0]) and is_instance_valid(pair[1]) and pair[0].is_inside_tree() and pair[1].is_inside_tree():
			pair[1].global_transform = pair[0].global_transform
			pair[1].visible = pair[0].is_visible_in_tree()
func _prism_parts(poly: PackedVector2Array, low: float, high: float) -> Dictionary:
	var top := SurfaceTool.new(); top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, poly.size() - 1):
		for p in [poly[0], poly[i], poly[i + 1]]:
			top.set_uv(p / 128.0); top.add_vertex(Vector3(p.x, high, p.y))
	top.generate_normals()
	var sides := SurfaceTool.new(); sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in poly.size():
		var a: Vector2 = poly[i]; var b: Vector2 = poly[(i + 1) % poly.size()]
		var quad := [[a, low], [b, low], [b, high], [a, high]]
		for k in [0,1,2,0,2,3]:
			var q: Array = quad[k]
			sides.set_uv(Vector2((q[0] as Vector2).distance_to(a) / 128.0, -float(q[1]) / 128.0)); sides.add_vertex(Vector3(q[0].x, float(q[1]), q[0].y))
	sides.generate_normals()
	var hull := PackedVector3Array()
	for p in poly: hull.append(Vector3(p.x, low, p.y)); hull.append(Vector3(p.x, high, p.y))
	return {"top":top.commit(),"sides":sides.commit(),"hull":hull}

## Fallback: the cave's indexed rock surface (every visible cave mesh must carry palette indices).
func _floor_material(_region: int) -> Material:
	return host._indexed_material(host.INDEX_ROOT + "material_134.png")

func present() -> void:
	# Removed prop83 must leave no solid trigger; save rewind restores it.
	for child in body.get_children():
		if child is CollisionShape3D: child.disabled = int(state.state) != 0
	if is_instance_valid(prop_instance): prop_instance.visible = int(state.state) == 0
	var h: float = float(state.shaft)
	var raised := h > State.SHAFT_START + 0.5
	for key in blocks:
		var blk: Dictionary = blocks[key]
		blk.body.position.y = h - State.SHAFT_TOP
		blk.body.visible = raised
		blk.shape.disabled = not raised
	if bool(state.opened) and not opened_applied: _apply_opening()
	elif not bool(state.opened) and opened_applied: _revert_opening()
	if host.get("stone_manafoil") != null: host.stone_manafoil.set_lift(h - State.SHAFT_START)
	_sync_mirrors()

func _in_wall(polys: Array, p: Vector2) -> bool:
	for poly in polys:
		if Geometry2D.is_point_in_polygon(p, poly): return true
		for i in poly.size():
			if Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p) < 1.5: return true
	return false

## Removes the vertical faces of the solid wall block (regions 1029..1033, -192..-32) from every host mesh and the
## host collision, then adds the opened floor at -192 and walls on the block's no-neighbour edges.
func _apply_opening() -> void:
	opened_applied = true
	var t: Vector3 = host.native_translation
	var polys: Array = []
	for key in ["1029","1030","1031","1032","1033"]: polys.append(_polygon(key))
	var lo := -192.0 + t.y - 1.0; var hi := -32.0 + t.y + 1.0
	var drop := func(a: Vector3, b: Vector3, c: Vector3) -> bool:
		var cen := (a + b + c) / 3.0
		if cen.y < lo or cen.y > hi: return false
		if absf((b - a).cross(c - a).normalized().y) >= 0.2: return false
		return _in_wall(polys, Vector2(cen.x, cen.z))
	var stack: Array = [host]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == self: continue
		for child in n.get_children(): stack.append(child)
		if n is MeshInstance3D and n.mesh is ArrayMesh: _filter_mesh(n, drop)
		elif n is CollisionShape3D and n.shape is ConcavePolygonShape3D and n.get_parent() != opened_body:
			var xf: Transform3D = n.global_transform; var inv := xf.affine_inverse()
			var faces: PackedVector3Array = n.shape.get_faces(); var kept := PackedVector3Array()
			for i in range(0, faces.size(), 3):
				if not drop.call(xf * faces[i], xf * faces[i + 1], xf * faces[i + 2]): kept.append_array([faces[i], faces[i + 1], faces[i + 2]])
			if kept.size() != faces.size():
				opening_backup.append({"node":n,"shape":n.shape})
				var shape := ConcavePolygonShape3D.new(); shape.backface_collision = n.shape.backface_collision; shape.set_faces(kept); n.shape = shape
	# The opened passage: floor at -192 and walls on edges without a neighbour (source neighbour None).
	var opened := StaticBody3D.new(); opened.name = "OpenedWall"; add_child(opened); opened_body = opened
	var collision := PackedVector3Array()
	var floors := SurfaceTool.new(); floors.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walls := SurfaceTool.new(); walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_wall := false
	for key in ["1029","1030","1031","1032","1033"]:
		var poly := _polygon(key)
		for i in range(1, poly.size() - 1):
			for p in [poly[0], poly[i], poly[i + 1]]:
				floors.set_uv(p / 128.0); floors.add_vertex(Vector3(p.x, -192.0 + t.y, p.y)); collision.append(Vector3(p.x, -192.0 + t.y, p.y))
		var neighbors: Array = source.regions[key].neighbors
		for i in poly.size():
			if neighbors[i] != null: continue
			any_wall = true
			var a: Vector2 = poly[i]; var b: Vector2 = poly[(i + 1) % poly.size()]
			var quad := [Vector3(a.x, -192.0 + t.y, a.y), Vector3(b.x, -192.0 + t.y, b.y), Vector3(b.x, -32.0 + t.y, b.y), Vector3(a.x, -32.0 + t.y, a.y)]
			for k in [0,1,2,0,2,3]:
				walls.set_uv(Vector2(quad[k].x + quad[k].z, -quad[k].y) / 128.0); walls.add_vertex(quad[k]); collision.append(quad[k])
	floors.generate_normals()
	var floor_mesh := MeshInstance3D.new(); floor_mesh.mesh = floors.commit(); floor_mesh.material_override = _surface_material(1037); floor_mesh.layers = 2; opened.add_child(floor_mesh); passage_pairs.append(_mirror(floor_mesh))
	if any_wall:
		walls.generate_normals()
		var wall_mesh := MeshInstance3D.new(); wall_mesh.mesh = walls.commit(); wall_mesh.material_override = _rock_material(); wall_mesh.layers = 2; opened.add_child(wall_mesh); passage_pairs.append(_mirror(wall_mesh))
	var shape := ConcavePolygonShape3D.new(); shape.backface_collision = true; shape.set_faces(collision)
	var col := CollisionShape3D.new(); col.shape = shape; opened.add_child(col)

## Rewrites a mesh with the dropped triangles collapsed (attributes and materials preserved).
func _filter_mesh(instance: MeshInstance3D, drop: Callable) -> void:
	var mesh: ArrayMesh = instance.mesh
	var xf: Transform3D = instance.global_transform
	var rebuilt := ArrayMesh.new(); var changed := false
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if mesh.surface_get_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES:
			if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array and not (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).is_empty():
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				for i in range(0, idx.size(), 3):
					if drop.call(xf * verts[idx[i]], xf * verts[idx[i + 1]], xf * verts[idx[i + 2]]):
						idx[i + 1] = idx[i]; idx[i + 2] = idx[i]; changed = true
				arrays[Mesh.ARRAY_INDEX] = idx
			else:
				for i in range(0, verts.size(), 3):
					if drop.call(xf * verts[i], xf * verts[i + 1], xf * verts[i + 2]):
						verts[i + 1] = verts[i]; verts[i + 2] = verts[i]; changed = true
				arrays[Mesh.ARRAY_VERTEX] = verts
		rebuilt.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays)
		rebuilt.surface_set_material(s, mesh.surface_get_material(s))
	if changed:
		opening_backup.append({"node":instance,"mesh":mesh})
		var overrides: Array = []
		for s in instance.get_surface_override_material_count(): overrides.append(instance.get_surface_override_material(s))
		instance.mesh = rebuilt
		for s in overrides.size(): instance.set_surface_override_material(s, overrides[s])

## Puts back every replaced host mesh/shape and removes the opened passage (loading a save from before the chain).
func _revert_opening() -> void:
	for entry in opening_backup:
		if not is_instance_valid(entry.node): continue
		if entry.has("mesh"): entry.node.mesh = entry.mesh
		else: entry.node.shape = entry.shape
	opening_backup.clear()
	for pair in passage_pairs:
		if pair.is_empty(): continue
		host.occluder_pairs.erase(pair)
		mirrored.erase(pair)
		if is_instance_valid(pair[1]): pair[1].get_parent().remove_child(pair[1]); pair[1].queue_free()
	passage_pairs.clear()
	if is_instance_valid(opened_body): remove_child(opened_body); opened_body.queue_free()
	opened_body = null
	opened_applied = false

func _aimed() -> bool:
	var target: Vector3 = body.global_position
	var delta: Vector3 = target - host.camera.global_position
	if delta.length() < 0.01 or delta.length() > REACH or (-host.camera.global_basis.z).dot(delta.normalized()) < 0.9: return false
	var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position, target, 1, [host.player.get_rid()])
	return host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

## Armed melee strike (kind9 g108, context 2/4). Returns true when the strike was taken by prop83.
func strike() -> bool:
	if host.flying or host.get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or (host.player_form == 0 and host.equipped_item == ""): return false
	if not _aimed(): return false
	if State.hit(state, 108, sound_seconds): sound.play()
	return true

## Spark ray (kind9 g124, context 1/1); also writes local25.
func receive_spark() -> bool:
	if State.hit(state, 124, sound_seconds):
		sound.play()
		return true
	return false

func _process(delta: float) -> void:
	if not is_instance_valid(sprite) or not sprite.visible or frames.is_empty(): return
	if not _world_active(): return
	frame_clock += delta
	var index := int(frame_clock / float(source.sprite.frame_seconds)) % frames.size()
	if index == frame_index: return
	frame_index = index
	sprite.material_override.set_shader_parameter("indices", frames[index])
	for pair in mirrored:
		if pair[0] == sprite and is_instance_valid(pair[1]): pair[1].material_override.set_shader_parameter("indices", frames[index])

func _player_feet() -> float:
	for child in host.player.get_children():
		if child is CollisionShape3D and child.shape != null:
			return host.player.global_position.y + child.position.y + child.shape.get_debug_mesh().get_aabb().position.y
	return host.player.global_position.y - 32.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(host) or not host.get("walkthrough_ready"): return
	if not _world_active():
		if sound.playing: sound.stream_paused = true
		return
	if sound.stream_paused: sound.stream_paused = false
	var before: float = float(state.shaft)
	if not State.advance(state, delta): return
	var rise: float = float(state.shaft) - before
	if rise > 0 and not host.flying:
		var t: Vector3 = host.native_translation
		var p: Vector3 = host.player.global_position
		for key in blocks:
			if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), _polygon(key)) and absf(_player_feet() - (before + t.y)) < 6.0:
				host.player.global_position.y += rise
				break
	present()
