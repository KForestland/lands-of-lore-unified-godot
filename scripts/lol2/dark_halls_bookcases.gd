extends Node3D
## Native kind-4 toggles; panel translation and E aiming are presentation/input adapters.
const SOURCE := "res://scripts/lol2/dark_halls_bookcases_source.json"
const NativeHost = preload("res://scripts/lol2/native_script_host.gd")
var host: Node3D
var native: RefCounted
var panels: Dictionary = {}
var source: Dictionary
var sound_log: Array[int] = []
var restoring := false

func setup(walkthrough: Node3D) -> String:
	host = walkthrough
	source = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var loaded: RefCounted = NativeHost.new()
	var error: String = loaded.load_area("res://scripts/lol2/native_scripts/L7_DH.json")
	if not error.is_empty(): return error
	native = loaded
	for row in source.controls:
		var id: String = str(int(row.control))
		native.bind_target("0x20:" + id, "movable:" + id)
		var panel := Node3D.new()
		panel.name = "Bookcase" + id
		add_child(panel)
		panels[id] = panel
		var area: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
		for face in area.faces:
			if str(face.get("placement_kind", "")) != "movable" or int(face.source_index) != int(id): continue
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in [0, 1, 2, 0, 2, 3]:
				surface.set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
				surface.add_vertex(Vector3(face.points[i][0], face.points[i][1], face.points[i][2]))
			var mesh := MeshInstance3D.new()
			mesh.mesh = surface.commit()
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			material.albedo_color = host.TINT
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir()+"/"+area.materials[face.material]))
			mesh.material_override = material
			panel.add_child(mesh)
		var body := StaticBody3D.new()
		body.collision_layer = preload("res://scripts/lol2/static_assemblies.gd").SCENERY_LAYER
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(row.size[0], row.size[1], row.size[2])
		shape.shape = box
		body.add_child(shape)
		body.position = Vector3(row.center[0], row.center[1], row.center[2])
		panel.add_child(body)
	host.player.collision_mask |= preload("res://scripts/lol2/static_assemblies.gd").SCENERY_LAYER
	native.sound_request.connect(_sound)
	restore_from_quests()
	return ""

func _sound(request: int) -> void:
	if restoring: return
	sound_log.append(request)
	print("Dark Halls bookcase sound request: ", request, " (logged)")

static func validate(value: Variant) -> String:
	if not value is Dictionary: return "Invalid Dark Halls bookcases."
	for id in value:
		if not str(id) in ["51", "58", "59"] or not value[id] is bool: return "Invalid Dark Halls bookcases."
	return ""

func is_open(id: String) -> bool:
	return bool(host.quest_state.get("dark_halls_bookcases", {}).get(id, false))

func restore_from_quests() -> void:
	if native == null: return
	restoring = true
	native.reset_state()
	for row in source.controls:
		var id: String = str(int(row.control))
		if is_open(id): native.fire_event("movable:" + id, 4, {"arg_c": 0, "context": "movable:" + id})
		panels[id].position = Vector3(row.direction[0], row.direction[1], row.direction[2]) * float(row.travel) if is_open(id) else Vector3.ZERO
	restoring = false

func aimed() -> String:
	var best := ""
	var score := 0.75
	for row in source.controls:
		var point: Vector3 = Vector3(row.center[0], row.center[1], row.center[2]) + panels[str(int(row.control))].position
		var offset: Vector3 = point - host.camera.global_position
		if offset.length() > 110.0: continue
		var query := PhysicsRayQueryParameters3D.create(host.camera.global_position, point, host.player.collision_mask)
		# Ignore the target leaf while checking the entire sight line. An oblique ray
		# enters this wide leaf before its center and can hide an intervening wall.
		var leaf: StaticBody3D = panels[str(int(row.control))].get_child(panels[str(int(row.control))].get_child_count() - 1)
		query.exclude = [host.player.get_rid(), leaf.get_rid()]
		var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): continue
		var dot: float = (-host.camera.global_basis.z).dot(offset.normalized())
		if dot > score: score = dot; best = str(int(row.control))
	return best

func use(id: String) -> bool:
	if native == null or not panels.has(id): return false
	if id != "58" and is_open(id): return true
	var result: Array = native.fire_event("movable:" + id, 4, {"arg_c": 0, "context": "movable:" + id})
	var ran := false
	for record in result:
		if record.status == "ran": ran = true
	if not ran: return false
	if not host.quest_state.has("dark_halls_bookcases"): host.quest_state.dark_halls_bookcases = {}
	host.quest_state.dark_halls_bookcases[id] = int(native.field("movable:"+id, "travel_0x50", 0)) > 0
	for row in source.controls:
		if str(int(row.control)) == id: panels[id].position = Vector3(row.direction[0], row.direction[1], row.direction[2]) * float(row.travel) if is_open(id) else Vector3.ZERO
	return true

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or get_tree().paused: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and use(aimed()):
		get_viewport().set_input_as_handled()
