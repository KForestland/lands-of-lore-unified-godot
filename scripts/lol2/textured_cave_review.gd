extends "res://scripts/lol2/original_walk_review.gd"

const WALL_ROOT := "res://assets/lol2/generated/wall_review/"
var native_walls: Node3D
var comparison_walls: Node3D
var ceiling_count := 0
var roof: MeshInstance3D
var wall_count := 0
var wall_materials: Dictionary = {}

func _ready() -> void:
	default_full_map = true
	super._ready()
	if not checkpoint_smoke: _jump_checkpoint(0)
	flight_label.position.y = 190
	if "--textured-smoke" in OS.get_cmdline_user_args():
		print("Textured cave: %d walls, %d ceilings, %d wall materials; existing collision retained" % [wall_count, ceiling_count, wall_materials.size()])
		get_tree().quit(0 if wall_count > 0 and ceiling_count == 1939 else 1)

func _show_shell_face(_points: Array) -> bool:
	# Rebuild visuals from explicit shell kinds below; retain all original collision.
	return false

func _load_pair() -> void:
	super._load_pair()
	native_walls = Node3D.new()
	comparison_walls = Node3D.new()
	stage.add_child(native_walls)
	stage.add_child(comparison_walls)
	comparison_walls.visible = false
	var neutral := StandardMaterial3D.new()
	neutral.cull_mode = BaseMaterial3D.CULL_DISABLED
	neutral.albedo_color = Color(0.35, 0.39, 0.43)
	var fallback := SurfaceTool.new()
	fallback.begin(Mesh.PRIMITIVE_TRIANGLES)
	fallback.set_material(neutral)
	for i in range(data.shell.size()):
		if data.shell[i].kind != "ceiling":
			var face: Array = fixtures[selected].shell[i]
			for index in [0, 1, 2, 0, 2, 3]: fallback.add_vertex(point(face[index]))
	fallback.generate_normals()
	var fallback_mesh := MeshInstance3D.new()
	fallback_mesh.mesh = fallback.commit()
	comparison_walls.add_child(fallback_mesh)
	if not FileAccess.file_exists(WALL_ROOT + "walls.json"):
		push_error("Wall assets missing: build the wall review assets first")
		get_tree().quit(1)
		return
	var wall_data = JSON.parse_string(FileAccess.get_file_as_string(WALL_ROOT + "walls.json"))
	# The walk fixture recenters native coordinates; recover its translation.
	var anchor: Dictionary = {}
	for face in data.faces:
		if int(face.region) == int(fixtures[selected].regions[0]):
			anchor = face
			break
	var translation := point(fixtures[selected].faces[0][0]) - point(anchor.points[0]) * 64.0
	_build_roof(translation)
	var groups: Dictionary = {}
	wall_count = 0
	for wall in wall_data.walls:
		var key := "%d_%d" % [int(wall.descriptor), int(wall.addressing)]
		if not groups.has(key):
			var path := WALL_ROOT + "material_%d_variant_0.png" % int(wall.descriptor)
			var image := Image.load_from_file(path)
			if image == null or image.is_empty():
				push_error("Missing wall image: " + path)
				get_tree().quit(1)
				return
			var material := ShaderMaterial.new()
			material.shader = load("res://scripts/lol2/wall_review.gdshader")
			material.set_shader_parameter("wall_texture", ImageTexture.create_from_image(image))
			material.set_shader_parameter("address_mode", int(wall.addressing))
			wall_materials[key] = material
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(material)
			groups[key] = surface
		var surface: SurfaceTool = groups[key]
		for index in [0, 1, 2, 0, 2, 3]:
			var uv: Array = wall.uv_unwrapped[index]
			surface.set_uv(Vector2(uv[0], uv[1]))
			surface.add_vertex(point(wall.points_godot[index]) + translation)
		wall_count += 1
	for surface in groups.values():
		var instance := MeshInstance3D.new()
		instance.mesh = surface.commit()
		native_walls.add_child(instance)
	label.text = "Textured cave — restoration preview\n%d recovered wall spans · T: compare provisional walls\nWASD: move · Shift: sprint · Mouse: look · Esc: release · R: reset\nF: fly · Space/Ctrl: fly up/down · N/P: checkpoints\nC: show/hide roof · Ceiling rock assignment provisional.\nFirst variants; lighting, transparency and collision unfinished." % wall_count

func _build_roof(translation: Vector3) -> void:
	# Original ceiling geometry; diagnostic rock material and planar UVs.
	var image := Image.load_from_file(WALL_ROOT + "material_134_variant_0.png")
	if image == null or image.is_empty():
		push_error("Roof preview requires recovered rock material 134")
		get_tree().quit(1)
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.albedo_color = Color(0.65, 0.65, 0.65)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	ceiling_count = 0
	for face in data.shell:
		if face.kind != "ceiling": continue
		for index in [0, 1, 2, 0, 2, 3]:
			var native_point := point(face.points[index]) * 64.0
			surface.set_uv(Vector2(native_point.x / image.get_width(), native_point.z / image.get_height()))
			surface.add_vertex(native_point + translation)
		ceiling_count += 1
	surface.generate_normals()
	roof = MeshInstance3D.new()
	roof.mesh = surface.commit()
	stage.add_child(roof)

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		roof.visible = not roof.visible
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		native_walls.visible = not native_walls.visible
		comparison_walls.visible = not native_walls.visible
