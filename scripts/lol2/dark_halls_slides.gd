extends Node3D
## Native kind-4 toggles; original template22 mode0/1 materials; state-to-mode and E aiming are adapters.
const SOURCE := "res://scripts/lol2/dark_halls_slides_source.json"
const NativeHost = preload("res://scripts/lol2/native_script_host.gd")
var host: Node3D
var native: RefCounted
var panels: Dictionary = {}
var variant_textures: Dictionary = {}
var source: Dictionary
var sound_log: Array[int] = []
var restoring := false

func setup(walkthrough: Node3D) -> String:
	host = walkthrough
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var loaded: RefCounted = NativeHost.new()
	var error: String = loaded.load_area("res://scripts/lol2/native_scripts/L7_DH.json")
	if not error.is_empty(): return error
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
	for key in [str(source.closed_material), str(source.open_material)]:
		variant_textures[key] = ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+pack.materials[key]))
	native = loaded
	for id in [416, 465]: native.bind_target("0x03:" + str(id), "prop:" + str(id))
	for row in source.controls:
		var id: String = str(int(row.control))
		native.bind_target("0x10:" + id, "control:" + id)
		var panel := Node3D.new()
		panel.name = "Slide" + id
		add_child(panel)
		panels[id] = panel
		var area: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
		for face in area.faces:
			if str(face.get("placement", "")) != "static_" + id: continue
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in [0, 1, 2, 0, 2, 3]:
				surface.set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
				surface.add_vertex(Vector3(face.points[i][0], face.points[i][1], face.points[i][2]))
			var mesh := MeshInstance3D.new()
			mesh.mesh = surface.commit()
			mesh.set_meta("source_face", int(face.face))
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			material.albedo_color = host.TINT
			if str(face.material) in area.alpha_cutout_materials: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+area.materials[face.material]))
			mesh.material_override = material
			panel.add_child(mesh)
	native.sound_request.connect(_sound)
	restore_from_quests()
	return ""

func _sound(request: int) -> void:
	if restoring: return
	sound_log.append(request)
	print("Dark Halls slide sound request: ", request, " (logged)")

static func validate(value: Variant) -> String:
	if not value is Dictionary: return "Invalid Dark Halls slides."
	for id in value:
		if not str(id) in ["236", "890", "891", "1013", "1015", "1041"] or not value[id] is bool: return "Invalid Dark Halls slides."
	return ""

func is_open(id: String) -> bool:
	return bool(host.quest_state.get("dark_halls_slides", {}).get(id, false))

func restore_from_quests() -> void:
	if native == null: return
	restoring = true
	native.reset_state()
	for row in source.controls:
		var id: String = str(int(row.control))
		if is_open(id): native.fire_event("control:" + id, 4, {"arg_c": 0, "context": "control:" + id})
		_pose(id)
	restoring = false

func _pose(id: String) -> void:
	var key: String = str(source.open_material) if is_open(id) else str(source.closed_material)
	for mesh: MeshInstance3D in panels[id].get_children():
		if int(mesh.get_meta("source_face")) in [int(source.variant_faces[0]), int(source.variant_faces[1])]:
			mesh.material_override.albedo_texture = variant_textures[key]

func aimed() -> String:
	var best := ""
	var score := 0.75
	for row in source.controls:
		var point := Vector3(row.center[0], row.center[1], row.center[2])
		var offset: Vector3 = point - host.camera.global_position
		if offset.length() > 110.0: continue
		var query := PhysicsRayQueryParameters3D.create(host.camera.global_position, point, host.player.collision_mask)
		query.exclude = [host.player.get_rid()]
		var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.position.distance_to(point) > 20.0: continue
		var dot: float = (-host.camera.global_basis.z).dot(offset.normalized())
		if dot > score: score = dot; best = str(int(row.control))
	return best

func use(id: String) -> bool:
	if native == null or not panels.has(id): return false
	var result: Array = native.fire_event("control:" + id, 4, {"arg_c": 0, "context": "control:" + id})
	var ran := false
	for record in result:
		if record.status == "ran": ran = true
	if not ran: return false
	if not host.quest_state.has("dark_halls_slides"): host.quest_state.dark_halls_slides = {}
	host.quest_state.dark_halls_slides[id] = int(native.field("control:"+id, "byte_0x25", 0)) == 1
	for row in source.controls:
		if str(int(row.control)) == id: _pose(id)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or get_tree().paused: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and use(aimed()):
		get_viewport().set_input_as_handled()
