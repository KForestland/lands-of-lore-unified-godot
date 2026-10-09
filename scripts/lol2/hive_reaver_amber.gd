extends Node3D
## Live Hive owner for the Reaver alcove (control121), its ceiling collapse and the Amber vein (control123).
## Saved as quests.hive_reaver_amber. E at an aimed control in reach takes the sword / one Amber. Corridor
## regions 364..370 get moving prisms (ceiling slabs hanging from the original ceiling, the alcove floor block) with
## collision; a ceiling stops above a player standing under it, and a rising floor carries a standing player.
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

static func assets_ready() -> bool:
	return FileAccess.file_exists("res://scripts/lol2/hive_reaver_amber_source.json") and FileAccess.file_exists(ROOT + "m0271.png") and FileAccess.file_exists(ROOT + "m0027.png") and FileAccess.file_exists(ROOT + "amber.png")

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
	if key == "121": return "E — Take the sword" if int(state.reaver.state) == 0 else ""
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
		if not State.take_reaver(state, collected): _feedback("You cannot carry more."); return true
		_feedback("Reaver of GO added to inventory.")
	else:
		if not int(state.amber.state) in [0,1,2]: _feedback("The amber vein is spent."); return true
		if State.harvest_amber(state, collected).is_empty(): _feedback("You cannot carry more amber."); return true
		_feedback("Amber added to inventory.")
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

func _process(_delta: float) -> void:
	var text := interaction_hint()
	if text.is_empty() or not is_instance_valid(host.get("interface_hud")): return
	if host.interface_hud.save_notice_remaining > 0.2: return
	host.interface_hud.hint.text = text
	host.interface_hud.save_notice_remaining = 0.2
