extends Node3D
const ROOT = "res://assets/lol2/generated/original_floors/"
var camera: Camera3D
var center := Vector3(0, -4, -170)
var radius := 230.0
var yaw := 0.0
var pitch := 1.25
var textured := true
var materials: Array[StandardMaterial3D] = []
var shell_nodes: Dictionary = {}
var frames := 0
var summary: Dictionary
var floor_faces: Array = []
var selection_label: Label
var examples := [10, 13, 30, 799]
var example_index := 0

func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "floors.json"))
	if not data is Dictionary:
		push_error("Run tools/lol2/import_original_floors.py first.")
		get_tree().quit(1)
		return
	summary = data.summary
	floor_faces = data.faces
	var groups: Dictionary = {}
	for face in data.faces:
		if not groups.has(face.material): groups[face.material] = []
		groups[face.material].append(face)
	for key in groups:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		material.texture_repeat = true
		if data.materials.has(key):
			var im := Image.load_from_file(ROOT + data.materials[key].path)
			im.generate_mipmaps() # Review-only minification, not native mip selection.
			material.albedo_texture = ImageTexture.create_from_image(im)
		else:
			material.albedo_color = Color(0.85, 0.15, 0.55)
		material.set_meta("saved_texture", material.albedo_texture)
		material.set_meta("saved_color", material.albedo_color)
		materials.append(material)
		var mesh := SurfaceTool.new()
		mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
		mesh.set_material(material)
		for face in groups[key]:
			for index in [0, 1, 2, 0, 2, 3]:
				var p = face.points[index]
				var uv = face.uv[index]
				mesh.set_uv(Vector2(uv[0], uv[1]))
				mesh.add_vertex(Vector3(p[0], p[1], p[2]))
		var instance := MeshInstance3D.new()
		instance.mesh = mesh.commit()
		add_child(instance)
	for kind in ["boundary", "ceiling", "interior"]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var neutral := StandardMaterial3D.new()
		neutral.cull_mode = BaseMaterial3D.CULL_DISABLED
		neutral.albedo_color = Color(0.35, 0.39, 0.43) if kind == "boundary" else Color(0.24, 0.27, 0.31)
		if kind == "interior": neutral.albedo_color = Color(0.75, 0.48, 0.16)
		surface.set_material(neutral)
		for face in data.shell:
			if face.kind != kind: continue
			for index in [0, 1, 2, 0, 2, 3]:
				var p = face.points[index]
				surface.add_vertex(Vector3(p[0], p[1], p[2]))
		surface.generate_normals()
		var instance := MeshInstance3D.new()
		instance.mesh = surface.commit()
		instance.visible = kind == "boundary" or (kind == "interior" and "--interior-review" in OS.get_cmdline_user_args())
		add_child(instance)
		shell_nodes[kind] = instance
	camera = Camera3D.new()
	camera.far = 3000
	camera.near = 0.02
	add_child(camera)
	camera.current = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.055, 0.065, 0.085)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 0.9
	add_child(light)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var label := Label.new()
	label.position = Vector2(18, 16)
	label.text = "Original cave floors — research review\n%d polygons | %d texture candidates | %d unresolved (pink)\nDrag: orbit · Wheel: zoom · Arrows: pan · T: textures\nRight-click floor: focus · N: next example · R: full map\nB: boundary walls · C: ceilings · I: candidate interior spans (amber)\nDiagnostic UVs / first variants. Neutral shell; interior wall spans and collision incomplete." % [summary.floor_quads, summary.with_texture_candidates, summary.unresolved]
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	selection_label = Label.new()
	selection_label.position = Vector2(18, 185)
	selection_label.text = "Select a floor to inspect its region. Camera inspection only; no collision."
	selection_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	selection_label.add_theme_constant_override("shadow_offset_x", 2)
	selection_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(selection_label)
	if "--room-capture" in OS.get_cmdline_user_args():
		_focus_region(13)
		shell_nodes["interior"].visible = true
	_update_camera()

func _update_camera() -> void:
	camera.position = center + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * radius
	camera.look_at(center)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch + event.relative.y * 0.005, 0.1, 1.5)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT: _pick_floor(event.position)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: radius = maxf(3, radius * 0.85)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: radius = minf(1000, radius / 0.85)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N:
			_focus_region(examples[example_index])
			example_index = (example_index + 1) % examples.size()
		if event.keycode == KEY_R:
			center = Vector3(0, -4, -170)
			radius = 230.0
			yaw = 0
			pitch = 1.25
			shell_nodes["boundary"].visible = true
			selection_label.text = "Full cave overview"
		if event.keycode == KEY_I: shell_nodes["interior"].visible = not shell_nodes["interior"].visible
		if event.keycode == KEY_B: shell_nodes["boundary"].visible = not shell_nodes["boundary"].visible
		if event.keycode == KEY_C: shell_nodes["ceiling"].visible = not shell_nodes["ceiling"].visible
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		textured = not textured
		for material in materials:
			material.albedo_texture = material.get_meta("saved_texture") if textured else null
			material.albedo_color = material.get_meta("saved_color") if textured else Color(0.55, 0.6, 0.65)

	_update_camera()

func _process(delta: float) -> void:
	if camera == null: return
	var movement := Vector3(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)), 0, float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	center += movement * radius * delta * 0.5
	_update_camera()
	frames += 1
	if frames == 5 and "--floor-smoke" in OS.get_cmdline_user_args():
		if summary.floor_quads != 1953 or summary.with_texture_candidates != 1860 or summary.ceilings != 1939 or summary.boundary_quads != 1338 or summary.interior_candidates != 955:
			get_tree().quit(1)
		else:
			print("Original floor review: 1953 quads, 1860 texture candidates, 1939 ceilings, 1338 boundary quads, 955 interior candidates, loaded successfully")
			get_tree().quit()

	if frames == 8 and ("--floor-capture" in OS.get_cmdline_user_args() or "--room-capture" in OS.get_cmdline_user_args()):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://captures")
		var filename := "original_room_review.png" if "--room-capture" in OS.get_cmdline_user_args() else "original_floor_review.png"
		get_viewport().get_texture().get_image().save_png("res://captures/" + filename)
		get_tree().quit()

func _point(p: Array) -> Vector3:
	return Vector3(p[0], p[1], p[2])

func _focus_region(region: int) -> void:
	for face in floor_faces:
		if int(face.region) != region: continue
		center = Vector3.ZERO
		for p in face.points: center += _point(p) * 0.25
		var extent := 0.0
		for p in face.points: extent = maxf(extent, center.distance_to(_point(p)))
		radius = clampf(extent * 3.5, 4.0, 25.0)
		pitch = 0.95
		shell_nodes["boundary"].visible = false
		shell_nodes["ceiling"].visible = false
		yaw = 0.4
		selection_label.text = "Region %d · material %s · cutaway (B/C restore shell) · I: candidate spans" % [region, face.material]
		return

func _pick_floor(screen: Vector2) -> void:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var nearest := INF
	var selected := -1
	for face in floor_faces:
		for indices in [[0, 1, 2], [0, 2, 3]]:
			var hit = Geometry3D.ray_intersects_triangle(origin, direction, _point(face.points[indices[0]]), _point(face.points[indices[1]]), _point(face.points[indices[2]]))
			if hit == null: continue
			var distance: float = origin.distance_squared_to(hit)
			if distance < nearest:
				nearest = distance
				selected = int(face.region)
	if selected >= 0: _focus_region(selected)
