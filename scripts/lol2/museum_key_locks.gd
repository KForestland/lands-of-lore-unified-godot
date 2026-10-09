extends Node3D
## Live owner for the 17 Museum Sk-key locks, the sconces they light and the movable55 SS1 panel.
## Source records: scripts/lol2/museum_key_locks_source.json. Saved as checkpoint "museum_key_locks".
## Modern adapters: E with the shared museum reach/aim/occlusion test, key/flame/panel markers, and
## immediate animation endpoints (no native kind8 timing). Insert needs the key in the hand cursor;
## take grants it into the hand cursor. Targets without host objects are listed in source.not_hosted.
const State = preload("res://scripts/lol2/museum_key_locks_state.gd")
const SOURCE := "res://scripts/lol2/museum_key_locks_source.json"
const ROOT := "res://assets/lol2/generated/museum_key_locks/"
const AIM_LIFT := 5.0
const PANEL_HEIGHT := 40.0 # Adapter: movable55 lowered pose is not replayed; x/z are the source placement.
var host: Node3D
var source: Dictionary
var state: Dictionary = State.initial()
var key_markers := {}
var flames: Array[MeshInstance3D] = []
var panel: Node3D
var panel_item: Sprite3D

var passage := {}

static func assets_ready() -> bool:
	return FileAccess.file_exists(SOURCE) and FileAccess.file_exists(ROOT + "sk_key.png") and FileAccess.file_exists(ROOT + "ss1.png") and FileAccess.file_exists(ROOT + "passage78.json")

static func passage_data() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(ROOT + "passage78.json"))

## Lock78 toggles prop81 (event20): closed = loaded floors 30/80 (shipped faces), open = opcode196 floors 0.
func _build_passage(faces: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := PackedVector3Array()
	for face in faces:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in [0, 1, 2, 0, 2, 3]:
			var p: Array = face.points[i]
			st.set_uv(Vector2(face.uv[i][0], face.uv[i][1]) if face.has("uv") else Vector2.ZERO)
			st.add_vertex(Vector3(p[0], p[1], p[2]))
			collision.append(Vector3(p[0], p[1], p[2]))
		var mesh := MeshInstance3D.new()
		mesh.mesh = st.commit()
		mesh.material_override = host.materials.get(face.material)
		body.add_child(mesh)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(collision)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body

func set_passage_open(open: bool) -> void:
	for pair in [[passage.closed, not open], [passage.open, open]]:
		var body: StaticBody3D = pair[0]
		body.visible = pair[1]
		body.process_mode = Node.PROCESS_MODE_INHERIT if pair[1] else Node.PROCESS_MODE_DISABLED
		for child in body.get_children():
			if child is CollisionShape3D: child.disabled = not pair[1]

func setup(owner: Node3D, saved: Variant = null) -> String:
	name = "MuseumKeyLocks"
	host = owner
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not source is Dictionary or int(source.version) != 1 or source.locks.size() != 17: return "Invalid key-lock source."
	for id in State.LOCKS:
		if not source.locks.has(str(id)): return "Key-lock source misses control %d." % id
	if source.initial_loaded != [87.0] and source.initial_loaded != [87]: return "Unexpected initial key lock."
	var key_texture := ImageTexture.create_from_image(Image.load_from_file(ROOT + "sk_key.png"))
	for id in State.LOCKS:
		var marker := Sprite3D.new()
		marker.texture = key_texture
		marker.pixel_size = 0.4
		marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		marker.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		marker.position = aim_point(id)
		add_child(marker)
		key_markers[id] = marker
	var flame_material := StandardMaterial3D.new()
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_material.albedo_color = Color(1.0, 0.62, 0.18)
	flame_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	for sconce in source.sconces.values():
		var flame := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(4, 7)
		flame.mesh = quad
		flame.material_override = flame_material
		var p: Array = sconce.position
		flame.position = Vector3(float(p[0]), float(p[1]) + 9.0, float(p[2]))
		add_child(flame)
		flames.append(flame)
	panel = Node3D.new()
	var place: Array = source.panel.position
	panel.position = Vector3(float(place[0]), PANEL_HEIGHT, float(place[2]))
	add_child(panel)
	panel_item = Sprite3D.new()
	panel_item.texture = ImageTexture.create_from_image(Image.load_from_file(ROOT + "ss1.png"))
	panel_item.pixel_size = 0.4
	panel_item.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	panel_item.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	panel.add_child(panel_item)
	var data := passage_data()
	passage = {"closed":_build_passage(data.closed_faces), "open":_build_passage(data.open_faces)}
	return restore_checkpoint(saved)

func restore_checkpoint(saved: Variant) -> String:
	var value = State.initial() if saved == null else saved
	var error := State.validate(value, host.carried_collected)
	if not error.is_empty(): return error
	state = State.canonical(value)
	present()
	return ""

func checkpoint() -> Dictionary: return state.duplicate(true)

func aim_point(id: int) -> Vector3:
	var p: Array = source.locks[str(id)].position
	return Vector3(float(p[0]), float(p[1]) + AIM_LIFT, float(p[2]))

func _ready_for_use() -> bool:
	if not is_instance_valid(host) or host.get_tree().paused or host.introduction_state != "complete": return false
	if is_instance_valid(host.interface_hud) and host.interface_hud.cursor_active: return false
	return host.starting_magic == null or host.starting_magic.world_active()

## The nearest lock or panel the player can reach and aim at, with the source group that would run.
func target() -> Dictionary:
	if not _ready_for_use(): return {}
	var best := {}
	var best_distance := INF
	for id in State.LOCKS:
		var point := aim_point(id)
		var kind := State.group(state, id, host.hand_item)
		if kind == "" or not host.can_reach_item(point): continue
		var distance: float = point.distance_to(host.camera.global_position)
		if distance < best_distance: best = {"lock":id,"group":kind}; best_distance = distance
	var panel_kind := State.panel_group(state, host.hand_item)
	if panel_kind != "" and host.can_reach_item(panel.global_position):
		var distance: float = panel.global_position.distance_to(host.camera.global_position)
		if distance < best_distance: best = {"panel":55,"group":panel_kind}
	return best

func interaction_hint() -> String:
	var t := target()
	match t.get("group", ""):
		"insert": return "E — Place Sk key in the lock"
		"take": return "E — Take Sk key"
		"give": return "E — Take SS1"
		"put_back": return "E — Return SS1"
	return ""

func use() -> bool:
	var t := target()
	if t.is_empty(): return false
	var inventory := {"collected":host.carried_collected,"hand":host.hand_item}
	if t.has("panel"):
		if State.run_panel(state, inventory).is_empty(): return false
	else:
		var effects := State.run(state, int(t.lock), inventory)
		if effects.is_empty(): return false
		if int(t.lock) == 140 and is_instance_valid(host.gallery):
			if effects[0] == "insert": host.gallery.lock_insert()
			else: host.gallery.lock_take()
	host.hand_item = inventory.hand
	present()
	if is_instance_valid(host.interface_hud) and host.interface_hud.has_method("refresh_equipment"): host.interface_hud.refresh_equipment()
	return true

func present() -> void:
	for id in key_markers: key_markers[id].visible = State.is_loaded(state, id)
	for flame in flames: flame.visible = State.sconces_lit(state)
	panel.visible = State.panel_lowered(state)
	panel_item.visible = int(state.panel_state) == 0
	if not passage.is_empty(): set_passage_open(State.is_loaded(state, 78))
