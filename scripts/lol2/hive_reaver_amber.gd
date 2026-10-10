extends Node3D
## Live Hive owner for the Reaver alcove (control121), its ceiling collapse and the Amber vein (control123).
## Saved as quests.hive_reaver_amber. E at an aimed control in reach takes the sword / one Amber. Corridor
## regions 364..370 get moving prisms (ceiling slabs hanging from the original ceiling, the alcove floor block) with
## collision; a ceiling stops above a player standing under it, and a rising floor carries a standing player.
## The four corridor support pillars (hive_reaver_pillars_source.json) take landed melee and Spark hits through
## non-blocking hit bodies (layers 4|8): each hit advances the pillar and nudges region365, starting the same
## collapse; the sword can then still be taken until the alcove seals.
const State = preload("res://scripts/lol2/hive_reaver_amber_state.gd")
const Items = preload("res://scripts/lol2/hive_amber_items.gd")
const ROOT := "res://assets/lol2/generated/hive_reaver_amber/"
const REACH := 110.0
var host: Node3D
var source: Dictionary
var state: Dictionary = State.initial()
var controls := {}
var slabs := {}
var materials := {}
var pillar_source: Dictionary
var pillars := {}
const PILLAR_LAYERS := 4 | 8

## One per pillar: the shared melee (hive_hit_receiver) and Spark (spark_receiver) dispatch call it.
class PillarReceiver extends RefCounted:
	var owner
	var id: String
	func receive_hit() -> bool: return owner.hit_pillar(id)
	func receive_spark() -> bool: return owner.hit_pillar(id)

static func assets_ready() -> bool:
	return FileAccess.file_exists("res://scripts/lol2/hive_reaver_amber_source.json") and FileAccess.file_exists(ROOT + "m0271.png") and FileAccess.file_exists(ROOT + "m0027.png") and FileAccess.file_exists(ROOT + "amber.png") and FileAccess.file_exists("res://scripts/lol2/hive_reaver_pillars_source.json") and FileAccess.file_exists(ROOT + "pillar.png")

func initial() -> Dictionary: return State.initial()
func checkpoint() -> Dictionary: return state.duplicate(true)

func setup(owner: Node3D, saved: Variant = null) -> String:
	name = "HiveReaverAmber"
	host = owner
	source = State.source()
	if not source is Dictionary or int(source.version) != 1: return "Invalid Reaver/Amber source."
	for key in ["121","123"]:
		var node := Node3D.new()
		add_child(node)
		var parts: Array = []
		for face in source.controls[key].faces:
			var mesh := MeshInstance3D.new()
			mesh.mesh = _quad(face.points, face.uv, _material(ROOT + str(face.material)))
			node.add_child(mesh)
			parts.append({"mesh":mesh,"mask":int(face.child_mask)})
		controls[key] = {"node":node,"parts":parts}
	for region in source.regions:
		for surface in ["floor","ceiling"]:
			var body := StaticBody3D.new()
			body.name = "Collapse_%s_%s" % [region, surface]
			add_child(body)
			var mesh := MeshInstance3D.new(); body.add_child(mesh)
			var shape := CollisionShape3D.new(); body.add_child(shape)
			slabs["%s:%s" % [region, surface]] = {"body":body,"mesh":mesh,"shape":shape,"shown":INF}
	pillar_source = State.pillar_source()
	if not pillar_source is Dictionary or int(pillar_source.get("version", 0)) != 1: return "Invalid Reaver pillar source."
	var texture := ImageTexture.create_from_image(Image.load_from_file(ROOT + str(pillar_source.image.file)))
	for id in State.PILLARS:
		var row: Dictionary = pillar_source.pillars[id]
		var p: Array = row.position
		var sprite := Sprite3D.new()
		sprite.name = "ReaverPillar%s" % id
		sprite.texture = texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.shaded = false
		var width := float(row.right) - float(row.left); var tall := float(row.top) - float(row.bottom)
		sprite.pixel_size = width / float(texture.get_width())
		sprite.scale.y = tall / (float(texture.get_height()) * sprite.pixel_size)
		sprite.flip_h = int(row.frame_flags) & 64 != 0
		sprite.position = Vector3(p[0], float(p[1]) + float(row.bottom) + tall / 2.0, p[2])
		add_child(sprite)
		# Hit-only body: melee (mask 7) and Hive Spark (mask 11) rays reach layers 4|8; the player does not collide.
		var body := StaticBody3D.new(); body.name = "ReaverPillarHit%s" % id
		body.collision_layer = PILLAR_LAYERS; body.collision_mask = 0
		var shape := CollisionShape3D.new(); var cylinder := CylinderShape3D.new()
		cylinder.radius = width * 0.25; cylinder.height = tall
		shape.shape = cylinder; body.add_child(shape)
		body.position = Vector3(p[0], float(p[1]) + float(row.bottom) + tall / 2.0, p[2])
		var receiver := PillarReceiver.new(); receiver.owner = self; receiver.id = id
		body.set_meta("hive_hit_receiver", receiver); body.set_meta("spark_receiver", receiver); body.set_meta("hive_reaver_pillar", id)
		add_child(body)
		pillars[id] = {"sprite":sprite,"body":body,"receiver":receiver}
	return restore(saved)

func restore(saved: Variant) -> String:
	var value = State.initial() if saved == null else saved
	var error := State.validate(value, source)
	if not error.is_empty(): return error
	state = State.canonical(value)
	present()
	return ""

func _material(path: String) -> StandardMaterial3D:
	if materials.has(path): return materials[path]
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(path))
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	materials[path] = m
	return m

func _host_material(id: Variant) -> Material:
	var host_materials = host.get("materials")
	if host_materials is Dictionary and host_materials.has(str(id)): return host_materials[str(id)]
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.25, 0.15, 0.1); m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _quad(points: Array, uv: Array, material: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	for index in [0,1,2,0,2,3]:
		st.set_uv(Vector2(uv[index][0], uv[index][1]))
		var p: Array = points[index]
		st.add_vertex(Vector3(p[0], p[1], p[2]))
	st.generate_normals()
	return st.commit()

## A vertical prism over a region polygon between two heights: cap (floor top / ceiling bottom) plus sides.
func _prism(region: String, low: float, high: float, cap_low: bool) -> Dictionary:
	var poly: Array = source.regions[region].polygon
	var mats: Dictionary = source.regions[region].materials
	var mesh := ArrayMesh.new()
	var cap := SurfaceTool.new(); cap.begin(Mesh.PRIMITIVE_TRIANGLES); cap.set_material(_host_material(mats.get("ceiling" if cap_low else "floor", "")))
	var y := low if cap_low else high
	for i in range(1, poly.size() - 1):
		for p in [poly[0], poly[i], poly[i + 1]]:
			cap.set_uv(Vector2(float(p[0]) / 128.0, float(p[1]) / 128.0)); cap.add_vertex(Vector3(float(p[0]), y, float(p[1])))
	cap.generate_normals(); cap.commit(mesh)
	var side := SurfaceTool.new(); side.begin(Mesh.PRIMITIVE_TRIANGLES); side.set_material(_host_material(mats.get("wall", "")))
	for i in poly.size():
		var a: Array = poly[i]; var b: Array = poly[(i + 1) % poly.size()]
		var length := Vector2(float(a[0]), float(a[1])).distance_to(Vector2(float(b[0]), float(b[1])))
		var quad := [[a, low, 0.0], [b, low, length], [b, high, length], [a, high, 0.0]]
		for k in [0,1,2,0,2,3]:
			var q: Array = quad[k]
			side.set_uv(Vector2(float(q[2]) / 128.0, -float(q[1]) / 128.0)); side.add_vertex(Vector3(float(q[0][0]), float(q[1]), float(q[0][1])))
	side.generate_normals(); side.commit(mesh)
	var hull := PackedVector3Array()
	for p in poly:
		hull.append(Vector3(float(p[0]), low, float(p[1]))); hull.append(Vector3(float(p[0]), high, float(p[1])))
	return {"mesh":mesh,"hull":hull}

func present() -> void:
	for part in controls["121"].parts: part.mesh.visible = (int(part.mask) >> State.reaver_selector(state)) & 1 == 1
	for part in controls["123"].parts: part.mesh.visible = (int(part.mask) >> State.amber_selector(state)) & 1 == 1
	for key in slabs:
		var slab: Dictionary = slabs[key]
		var region: String = key.get_slice(":", 0); var surface: String = key.get_slice(":", 1)
		var h := State.height(state, int(region), surface)
		if h == slab.shown: continue
		slab.shown = h
		var low := State.ORIGINAL.floor if surface == "floor" else h
		var high := h if surface == "floor" else State.ORIGINAL.ceiling
		if high - low < 0.5:
			slab.mesh.mesh = null; slab.shape.shape = null; slab.body.visible = false
			continue
		var prism := _prism(region, low, high, surface == "ceiling")
		slab.mesh.mesh = prism.mesh
		var shape := ConvexPolygonShape3D.new(); shape.points = prism.hull
		slab.shape.shape = shape
		slab.body.visible = true

func aim_point(key: String) -> Vector3:
	var faces: Array = source.controls[key].faces
	var sum := Vector3.ZERO; var count := 0
	for face in faces:
		for p in face.points: sum += Vector3(p[0], p[1], p[2]); count += 1
	return sum / maxf(count, 1)

func _active() -> bool:
	if not is_instance_valid(host) or host.get_tree().paused or host.get("flying") or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if host.has_method("actor_input_locked") and host.actor_input_locked(): return false
	if host.get("interface_hud") != null and is_instance_valid(host.interface_hud) and host.interface_hud.get("cursor_active"): return false
	if host.has_node("Warriors") and host.get_node("Warriors").health == 0: return false
	return true

func target() -> String:
	if not _active(): return ""
	for key in ["121","123"]:
		var point := aim_point(key)
		var offset: Vector3 = point - host.camera.global_position
		if offset.length() < 0.01 or offset.length() > REACH: continue
		if (-host.camera.global_basis.z).dot(offset.normalized()) < 0.95: continue
		var ray := PhysicsRayQueryParameters3D.create(host.camera.global_position, point, 1, [host.player.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or (hit.position as Vector3).distance_to(point) < 8.0: return key
	return ""

func interaction_hint() -> String:
	var key := target()
	if key == "121":
		if int(state.reaver.state) != 0: return ""
		return "The alcove has sealed over the sword." if State.alcove_sealed(state) else "E — Take the sword"
	if key == "123": return "E — Take amber" if int(state.amber.state) in [0,1,2] else "The amber vein is spent."
	return ""

## Shared HUD notice convention: the hint line holds while save_notice_remaining is positive.
func _feedback(text: String) -> void:
	if not is_instance_valid(host.get("interface_hud")): return
	host.interface_hud.hint.text = text
	host.interface_hud.save_notice_remaining = 2.5

func use() -> bool:
	var key := target()
	if key.is_empty(): return false
	var collected: Array = host.carried_inventory.collected
	if key == "121":
		if int(state.reaver.state) != 0: return false
		if State.alcove_sealed(state): _feedback("The alcove has sealed over the sword."); return true
		if not State.take_reaver(state, collected): _feedback("You cannot carry more."); return true
		_feedback("Reaver of GO added to inventory.")
	else:
		if not int(state.amber.state) in [0,1,2]: _feedback("The amber vein is spent."); return true
		if State.harvest_amber(state, collected).is_empty(): _feedback("You cannot carry more amber."); return true
		_feedback("Amber added to inventory.")
	present()
	return true

## Landed player hit (melee or Spark) on a corridor pillar: source state record + region365 nudge. World gate only.
func hit_pillar(id: String) -> bool:
	if not _active() or not State.hit_pillar(state, source, pillar_source, id): return false
	_feedback("The cracked pillar shudders.")
	present()
	return true

## Player body extent (feet/head) from its collision shape.
func _player_span() -> Vector2:
	var top := 32.0; var bottom := -32.0
	for child in host.player.get_children():
		if child is CollisionShape3D and child.shape != null:
			var aabb: AABB = child.shape.get_debug_mesh().get_aabb()
			top = child.position.y + aabb.end.y; bottom = child.position.y + aabb.position.y
			break
	return Vector2(host.player.global_position.y + bottom, host.player.global_position.y + top)

func _player_in(region: String) -> bool:
	var polygon := PackedVector2Array()
	for p in source.regions[region].polygon: polygon.append(Vector2(float(p[0]), float(p[1])))
	var pos: Vector3 = host.player.global_position
	return Geometry2D.is_point_in_polygon(Vector2(pos.x, pos.z), polygon)

## Native B861C blocks a surface move that an occupant does not fit under.
func _blocked(key: String, next: float) -> bool:
	var region := key.get_slice(":", 0)
	if key.get_slice(":", 1) != "ceiling" or not _player_in(region): return false
	return next < _player_span().y + 2.0

func _physics_process(delta: float) -> void:
	if not _active(): return
	var was_sealed := State.alcove_sealed(state)
	var floor_key := ""
	var before := 0.0
	for region in source.regions:
		if _player_in(region) and state.collapse.movers.has(region + ":floor"):
			floor_key = region + ":floor"; before = State.height(state, int(region), "floor")
	if State.advance(state, delta, source, _blocked):
		if not floor_key.is_empty():
			var rise := State.height(state, int(floor_key.get_slice(":", 0)), "floor") - before
			if rise > 0 and absf(_player_span().x - before) < 4.0: host.player.global_position.y += rise
		present()
		if not was_sealed and State.alcove_sealed(state) and int(state.reaver.state) == 0:
			_feedback("The alcove has sealed over the sword.")

func _process(_delta: float) -> void:
	var text := interaction_hint()
	if text.is_empty() or not is_instance_valid(host.get("interface_hud")): return
	if host.interface_hud.save_notice_remaining > 0.2: return
	host.interface_hud.hint.text = text
	host.interface_hud.save_notice_remaining = 0.2
