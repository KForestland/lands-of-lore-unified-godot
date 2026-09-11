extends "res://scripts/lol2/original_walk_review.gd"

const WALL_ROOT := "res://assets/lol2/generated/wall_review/"
var native_walls: Node3D
var comparison_walls: Node3D
var prop_capture := false
var prop_capture_frames := 0
var props_root: Node3D
var prop_count := 0
var prop_centers: Dictionary = {}
var ceiling_count := 0
var roof: MeshInstance3D
var wall_count := 0
var wall_materials: Dictionary = {}

func _ready() -> void:
	default_full_map = true
	super._ready()
	if not checkpoint_smoke:
		var initial_checkpoint := 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--checkpoint="):
				var value := argument.trim_prefix("--checkpoint=")
				if not value.is_valid_int() or int(value) < 1 or int(value) > fixtures[0].checkpoints.size():
					push_error("Checkpoint must be between 1 and %d" % fixtures[0].checkpoints.size())
					get_tree().quit(1)
					return
				initial_checkpoint = int(value) - 1
		_jump_checkpoint(initial_checkpoint)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prop-record="):
			var value := argument.trim_prefix("--prop-record=")
			if not value.is_valid_int() or not prop_centers.has(int(value)):
				push_error("Prop record is not in this preview")
				get_tree().quit(1)
				return
			prop_capture = "--walk-capture" in OS.get_cmdline_user_args()
			var center: Vector3 = prop_centers[int(value)]
			await get_tree().physics_frame
			_place_prop_camera(center)
			flying = true
			flight_label.text = "Prop %s inspection · fly mode · F returns to walking" % value
	flight_label.position.y = 215
	if "--textured-smoke" in OS.get_cmdline_user_args():
		print("Textured cave: %d walls, %d ceilings, %d wall materials; existing collision retained" % [wall_count, ceiling_count, wall_materials.size()])
		get_tree().quit(0 if wall_count > 0 and ceiling_count == 1939 and prop_count == 1171 else 1)

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
	_build_props(translation)
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
	label.text = "Textured cave — restoration preview\n%d recovered wall spans · T: compare provisional walls\nWASD: move · Shift: sprint · Mouse: look · Esc: release · R: reset\nF: fly · Space/Ctrl: fly up/down · N/P: checkpoints\nC: roof · B: props (1171 static preview placements).\nRoof material, prop alpha/orientation, lighting and collision provisional." % wall_count

func _build_props(translation: Vector3) -> void:
	props_root = Node3D.new()
	stage.add_child(props_root)
	var root := "res://assets/lol2/generated/prop_review/"
	if not FileAccess.file_exists(root + "props.json"):
		push_error("Prop preview assets missing: run export_cave_prop_preview.py")
		get_tree().quit(1)
		return
	var catalog = JSON.parse_string(FileAccess.get_file_as_string(root + "props.json"))
	var materials: Dictionary = {}
	prop_count = 0
	for prop in catalog.props:
		var id := int(prop.descriptor)
		var flags := int(prop.frame_flags) & 0xC0
		var key := "%d:%d" % [id, flags]
		if not materials.has(key):
			var image := Image.load_from_file(root + "prop_%d.png" % id)
			if image == null or image.is_empty():
				push_error("Prop image missing")
				get_tree().quit(1)
				return
			var material := StandardMaterial3D.new()
			material.albedo_texture = ImageTexture.create_from_image(image)
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.5
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
			# Native 129AC8 setup: 0x40 reverses columns, 0x80 reverses rows.
			material.uv1_scale = Vector3(-1.0 if flags & 0x40 else 1.0, -1.0 if flags & 0x80 else 1.0, 1.0)
			material.uv1_offset = Vector3(1.0 if flags & 0x40 else 0.0, 1.0 if flags & 0x80 else 0.0, 0.0)
			materials[key] = material
		var quad := QuadMesh.new()
		quad.size = Vector2(float(prop.right) - float(prop.left), float(prop.top) - float(prop.bottom))
		quad.center_offset = Vector3((float(prop.left) + float(prop.right)) / 2, (float(prop.bottom) + float(prop.top)) / 2, 0)
		quad.material = materials[key]
		var instance := MeshInstance3D.new()
		instance.mesh = quad
		instance.position = point(prop.position_native) + translation
		props_root.add_child(instance)
		prop_centers[int(prop.record)] = instance.position + quad.center_offset
		prop_count += 1
	print("Static prop preview: %d instances" % prop_count)

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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		props_root.visible = not props_root.visible
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		roof.visible = not roof.visible
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		native_walls.visible = not native_walls.visible
		comparison_walls.visible = not native_walls.visible

func _process(_delta: float) -> void:
	if prop_capture:
		prop_capture_frames += 1
		if prop_capture_frames == 30:
			DirAccess.make_dir_recursive_absolute("res://captures")
			get_viewport().get_texture().get_image().save_png("res://captures/prop_preview.png")
			get_tree().quit()

func _place_prop_camera(center: Vector3) -> void:
	# Query after the scene collision has entered the physics world.
	# Keep the original +Z view when clear; otherwise choose more open space.
	var space := get_world_3d().direct_space_state
	var best_direction := Vector3.BACK
	var best_distance := 0.0
	for index in range(16):
		var angle := float(index) * TAU / 16.0
		var direction := Vector3(sin(angle), 0, cos(angle))
		var query := PhysicsRayQueryParameters3D.create(center, center + direction * 116.0)
		query.exclude = [player.get_rid()]
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		var distance := 110.0
		if not hit.is_empty():
			distance = maxf(0.0, center.distance_to(hit.position) - 6.0)
		if distance > best_distance:
			best_distance = distance
			best_direction = direction
		if best_distance >= 110.0:
			break
	if best_distance < 8.0:
		push_warning("Prop center has no clear horizontal inspection view")
	player.global_position = center + best_direction * maxf(best_distance, 1.0) - Vector3(0, 24, 0)
	player.rotation = Vector3(0, atan2(best_direction.x, best_direction.z), 0)
	camera.rotation = Vector3.ZERO
	print("Prop inspection camera clearance: %.1f units" % best_distance)
