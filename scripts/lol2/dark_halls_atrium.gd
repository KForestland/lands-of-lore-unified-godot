extends Node
## Meta duck: pull the chain by the dead trees, the roof splits, sunlight hits the bed, and the bell fruit grows.
## Exact: control 252 kind 5 is group 8526, one opcode 20 (sound 1084 on prop 639).
## Roof opens are kind-6 value 15 on movables 52-55. Group 8526 does not name them.
## Opcode 18 stores the command and its reader was not entered. The X word and the Y dword match the open pose.
## Opcode 204 arm -1 on the bed regions calls 0xB861C, which is unread. Grass is the longplay bed.
## Group 12686 (value 15) has twenty-one opcode 14 timers on prop 217. Group 13062 is value 6 and its timers sit on prop 218, so the pull does not run them. The fruit sprites are prop_114 records 220-231.
## BH09: sunlight kills roaming shades under the opened roof (hintbook intent adapter; no kill in these groups).
const SOURCE := "res://scripts/lol2/dark_halls_atrium_source.json"
const REACH := 120.0
const FACING := 0.7
var host: Node3D
var source: Dictionary = {}
var chain := Vector3.ZERO
var panels: Dictionary = {}
var homes: Dictionary = {}
var bed_meshes: Array[MeshInstance3D] = []
var soil: StandardMaterial3D
var grass: StandardMaterial3D
var fruit_material: StandardMaterial3D
var frame_paths: Array[String] = []
var textures: Dictionary = {}
var opened := false
var sound_id := 0
var light_volume := AABB()
var bare_fruit: Texture2D

func setup(walkthrough: Node3D) -> String:
	host = walkthrough
	name = "DarkHallsAtrium"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not parsed is Dictionary:
		return "Dark Halls atrium source missing."
	source = parsed
	var area_v: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(host.get("geometry_file"))))
	if not area_v is Dictionary:
		return "Dark Halls geometry missing."
	var area: Dictionary = area_v
	var root := str(host.geometry_file).get_base_dir() + "/"
	soil = _lit(root + str(area.materials[host.GARDEN_BED_SOIL]))
	grass = _lit(root + str(area.materials[host.GARDEN_BED_GRASS]))
	var anim: Dictionary = area.animations.prop_114
	for frame_v in anim.frames:
		frame_paths.append(root + str(frame_v))
	if frame_paths.size() != 25 or int(source.fruit_frame) >= frame_paths.size():
		return "Dark Halls atrium fruit frames are short."
	var fruit_ids: Dictionary = {}
	for id_v in source.fruit:
		fruit_ids[int(id_v)] = true
	var chain_box := AABB()
	var seen_chain := false
	var bed_triangles := PackedVector3Array()
	var bed_regions: Array = host.GARDEN_BED_REGIONS
	for face_v in area.faces:
		var face: Dictionary = face_v
		var sid := int(face.get("source_index", -1))
		if str(face.get("placement_kind", "")) == "movable" and sid >= 52 and sid <= 55 and str(face.get("kind", "")) == "movable":
			_add_panel_face(sid, face, root, area)
		elif str(face.get("placement_kind", "")) == "static_assembly" and sid == int(source.chain):
			for point_v in face.points:
				var point: Array = point_v
				var at := Vector3(float(point[0]), float(point[1]), float(point[2]))
				if not seen_chain:
					chain_box = AABB(at, Vector3.ZERO)
					seen_chain = true
				else:
					chain_box = chain_box.expand(at)
		elif str(face.get("kind", "")) == "floor" and str(face.get("material", "")) == str(host.GARDEN_BED_SOIL) and int(face.get("region", -1)) in bed_regions:
			if face.get("points", []).size() != 4 or face.get("uv", []).size() != 4:
				return "Dark Halls garden bed must be a quad."
			var floor_mesh := _mesh(face, soil)
			add_child(floor_mesh)
			bed_meshes.append(floor_mesh)
			for index in _triangle_indices(face):
				var point:Array=face.points[index]
				bed_triangles.append(Vector3(point[0],point[1],point[2]))
	if not seen_chain or bed_meshes.size() != 24 or panels.size() != 4:
		return "Dark Halls atrium geometry is short."
	chain = chain_box.get_center()
	var props: Dictionary = host.prop_nodes
	var fruit := 0
	for record_v in props.keys():
		if not fruit_ids.has(int(record_v)):
			continue
		var node := props[record_v] as MeshInstance3D
		if node == null or node.mesh == null:
			continue
		var mat := node.mesh.material as StandardMaterial3D
		if mat == null:
			continue
		fruit += 1
		fruit_material = mat
	if fruit != 12 or fruit_material == null:
		return "Dark Halls atrium fruit count is %d." % fruit
	# The host removes these source quads from its static pass so this owner
	# can switch soil to grass. Keep their walking surface here too. Separate
	# body: adding faces to the main terrain trimesh changes remote contacts.
	if bed_triangles.size() != 144:
		return "Dark Halls garden collision must have 144 vertices."
	var terrain: StaticBody3D
	for child in host.get_children():
		if child is StaticBody3D and child.name != "RegionBlockers":
			for shape in child.get_children():
				if shape is CollisionShape3D and shape.shape is ConcavePolygonShape3D:
					terrain = child
					break
		if terrain != null: break
	if terrain == null:
		return "Dark Halls garden terrain collision missing."
	var bed_body := StaticBody3D.new()
	bed_body.name = "GardenBedFloorCollision"
	bed_body.collision_layer = terrain.collision_layer
	bed_body.collision_mask = terrain.collision_mask
	var bed_shape := ConcavePolygonShape3D.new()
	# Match jungle_review.gd build_geometry: the surrounding terrain is two-sided.
	bed_shape.backface_collision = true
	bed_shape.set_faces(bed_triangles)
	var bed_collision := CollisionShape3D.new()
	bed_collision.shape = bed_shape
	bed_body.add_child(bed_collision)
	add_child(bed_body)
	bare_fruit = fruit_material.albedo_texture
	for sid in homes:
		light_volume = homes[sid] if light_volume.size == Vector3.ZERO else light_volume.merge(homes[sid])
	var roof_y := light_volume.position.y
	var floor_y := roof_y
	for face in area.faces:
		if str(face.get("kind", "")) == "floor" and int(face.get("region", -1)) in bed_regions:
			for point in face.points: floor_y = minf(floor_y, float(point[1]))
	light_volume.position.y = floor_y
	light_volume.size.y = roof_y - floor_y
	restore_from_quests()
	return ""

func _add_panel_face(sid: int, face: Dictionary, root: String, area: Dictionary) -> void:
	var panel: Node3D = panels.get(sid, null)
	if panel == null:
		panel = Node3D.new()
		panel.name = "Roof" + str(sid)
		add_child(panel)
		panels[sid] = panel
	var box: AABB = homes.get(sid, AABB())
	var have: bool = homes.has(sid)
	for point_v in face.points:
		var point: Array = point_v
		var at := Vector3(float(point[0]), float(point[1]), float(point[2]))
		if not have:
			box = AABB(at, Vector3.ZERO)
			have = true
		else:
			box = box.expand(at)
	homes[sid] = box
	var key := str(face.get("material", ""))
	if not textures.has(key):
		textures[key] = _lit(root + str(area.materials[key]))
	panel.add_child(_mesh(face, textures[key]))

## The same source fan and coordinate space for the drawn and solid quads.
func _triangle_indices(face: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for i in range(1, face.points.size() - 1):
		result.append_array([0, i, i+1])
	return result

func _mesh(face: Dictionary, material: Material) -> MeshInstance3D:
	var pts: Array = face.points
	var uvs: Array = face.uv
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in _triangle_indices(face):
		var uv: Array = uvs[k]
		surface.set_uv(Vector2(float(uv[0]), float(uv[1])))
		var point: Array = pts[k]
		surface.add_vertex(Vector3(float(point[0]), float(point[1]), float(point[2])))
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = material
	return mesh

func _lit(path: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(path))
	material.albedo_color = host.TINT
	return material

func is_open() -> bool:
	return opened

func center_of(movable: int) -> Vector3:
	var box: AABB = homes[movable]
	return box.get_center() + (panels[movable] as Node3D).position

static func validate(value: Variant) -> String:
	if not value is Dictionary:
		return "Invalid Dark Halls atrium."
	var bag: Dictionary = value
	if int(bag.get("version", -1)) != 1:
		return "Invalid Dark Halls atrium."
	if not bag.get("open", false) is bool:
		return "Invalid Dark Halls atrium."
	if bag.has("sound") and int(bag.sound) != 1084:
		return "Invalid Dark Halls atrium."
	return ""

func restore_from_quests() -> void:
	var saved_v: Variant = host.quest_state.get("dark_halls_atrium") if host != null else null
	if saved_v is Dictionary and bool((saved_v as Dictionary).get("open", false)):
		_apply_open()
	else:
		opened = false
		sound_id = 0
		for panel in panels.values(): panel.position = Vector3.ZERO
		for mesh in bed_meshes: mesh.material_override = soil
		fruit_material.albedo_texture = bare_fruit

func open_roof() -> bool:
	if opened:
		return false
	_apply_open()
	var quests: Dictionary = host.quest_state
	quests["dark_halls_atrium"] = {"version": 1, "open": true, "sound": int(source.sound)}
	apply_sunlight()
	return true

func _apply_open() -> void:
	opened = true
	sound_id = int(source.sound)
	for row_v in source.panels:
		var row: Dictionary = row_v
		var sid := int(row.movable)
		var box: AABB = homes[sid]
		var center := box.get_center()
		var panel := panels[sid] as Node3D
		panel.position = Vector3(float(row.x) - center.x, 0.0, -float(row.y) - center.z)
	for mesh in bed_meshes:
		mesh.material_override = grass
	fruit_material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(frame_paths[int(source.fruit_frame)]))

func _unhandled_input(event: InputEvent) -> void:
	if (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless") or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and _aimed() and open_roof():
		get_viewport().set_input_as_handled()

func _aimed() -> bool:
	if host == null or not host.get("camera") is Camera3D or opened:
		return false
	var camera := host.get("camera") as Camera3D
	var offset := chain - camera.global_position
	if offset.length() > REACH or offset.length() < 0.01:
		return false
	return (-camera.global_basis.z).dot(offset.normalized()) > FACING

func apply_sunlight() -> Array[String]:
	var killed: Array[String] = []
	if not opened: return killed
	var population := host.get("creatures") as Node
	if population == null: return killed
	for row in population.src.actors:
		var id := str(int(row.actor))
		if int(row.definition) != 0 or int(population.state.actors[id].health) <= 0: continue
		if light_volume.has_point(population.bodies[id].global_position):
			if population.environment_damage(id, int(population.state.actors[id].health)) > 0: killed.append(id)
	return killed

func _physics_process(_delta: float) -> void:
	if opened and host != null and host.starting_magic != null and host.starting_magic.world_active():
		apply_sunlight()
