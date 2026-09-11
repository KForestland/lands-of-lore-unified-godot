extends Node3D
@export var default_full_map := false
const WALK_SPEED = 80.0
const SPRINT_SPEED = 144.0
const ROOT = "res://assets/lol2/generated/original_floors/"
var fixtures: Array
var data: Dictionary
var stage: Node3D
var player: CharacterBody3D
var camera: Camera3D
var label: Label
var selected := 0
var start := Vector3.ZERO
var target := Vector3.ZERO
var ticks := 0
var grounded := false
var resets := 0
var smoke := false
var capture := false
var completed := 0
var connected := false
var full_map := false
var flying := false
var checkpoint := -1
var checkpoint_smoke := false
var material_cache: Dictionary = {}
var surface_groups: Dictionary = {}
var flight_label: Label
var waypoint := 0
var route_ticks := 0
var route_limit := 240
func point(p: Array) -> Vector3:
	return Vector3(p[0], p[1], p[2])
func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "floors.json"))
	full_map = default_full_map or "--full-map" in OS.get_cmdline_user_args()
	connected = full_map or "--connected" in OS.get_cmdline_user_args()
	fixtures = JSON.parse_string(FileAccess.get_file_as_string(ROOT + ("full_walk.json" if full_map else ("connected_walk.json" if connected else "traversal_expanded.json"))))
	checkpoint_smoke = "--checkpoint-smoke" in OS.get_cmdline_user_args()
	smoke = checkpoint_smoke or "--walk-smoke" in OS.get_cmdline_user_args()
	capture = "--walk-capture" in OS.get_cmdline_user_args()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.055, 0.065, 0.085)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	add_child(light)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(18, 16)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	flight_label = Label.new()
	flight_label.position = Vector2(18, 155)
	canvas.add_child(flight_label)
	_load_pair()
	if checkpoint_smoke: _jump_checkpoint(0)
	if not smoke and not capture: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _load_pair() -> void:
	if stage != null:
		remove_child(stage)
		stage.queue_free()
	stage = Node3D.new()
	add_child(stage)
	surface_groups.clear()
	var fixture: Dictionary = fixtures[selected]
	var collision_faces := PackedVector3Array()
	for i in range(fixture.regions.size()):
		var source: Dictionary = {}
		for face in data.faces:
			if int(face.region) == int(fixture.regions[i]): source = face; break
		var material: StandardMaterial3D
		if material_cache.has(source.material): material = material_cache[source.material]
		else:
			material = StandardMaterial3D.new()
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			if data.materials.has(source.material):
				var im := Image.load_from_file(ROOT + data.materials[source.material].path)
				im.generate_mipmaps()
				material.albedo_texture = ImageTexture.create_from_image(im)
			else: material.albedo_color = Color(0.85, 0.15, 0.55)
			material_cache[source.material] = material
		_add_face(fixture.faces[i], material, collision_faces, source.uv)
	var neutral := StandardMaterial3D.new()
	neutral.cull_mode = BaseMaterial3D.CULL_DISABLED
	neutral.albedo_color = Color(0.35, 0.39, 0.43)
	for face in fixture.shell:
		if _show_shell_face(face):
			_add_face(face, neutral, collision_faces)
		else:
			for index in [0, 1, 2, 0, 2, 3]: collision_faces.append(point(face[index]))
	for surface in surface_groups.values():
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		stage.add_child(mesh)
	if connected:
		var lines := ImmediateMesh.new()
		var amber := StandardMaterial3D.new()
		amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		amber.albedo_color = Color(1, 0.6, 0.1)
		lines.surface_begin(Mesh.PRIMITIVE_LINES, amber)
		for opening in fixture.exits:
			var a := point(opening.points[0]) + Vector3.UP * 1
			var b := point(opening.points[1]) + Vector3.UP * 1
			for p in [a, b, a, a + Vector3.UP * 64, b, b + Vector3.UP * 64]: lines.surface_add_vertex(p)
		lines.surface_end()
		var markers := MeshInstance3D.new()
		markers.mesh = lines
		stage.add_child(markers)
	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(collision_faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	stage.add_child(body)
	player = CharacterBody3D.new()
	player.safe_margin = 0.05
	player.floor_snap_length = 4
	var capsule := CapsuleShape3D.new()
	capsule.radius = 8
	capsule.height = 64
	var player_shape := CollisionShape3D.new()
	player_shape.shape = capsule
	player.add_child(player_shape)
	stage.add_child(player)
	camera = Camera3D.new()
	camera.position.y = 24
	camera.near = 0.5
	camera.far = 30000 if full_map else 5000
	player.add_child(camera)
	camera.current = true
	start = point(fixture.start)
	target = point(fixture.end)
	_reset()
	label.text = "Original cave — experimental local walk (%d/%d)\nRegions %d / %d · %s seam\nWASD: move · Shift: sprint · Mouse: look · Esc: release mouse · Click: capture\nR: reset · N/P: next/previous pair · Falls reset automatically\nTwo-region samples only. Assumed player size; provisional walls and floor UVs." % [selected + 1, fixtures.size(), fixture.regions[0], fixture.regions[1], fixture.kind]
	if connected:
		label.text = "Original cave — connected experimental walk\n%d original regions · amber edges: exits into omitted geometry\nWASD: move · Shift: sprint · Mouse: look · Esc: release · Click: capture · R: reset\nAssumed player size; diagnostic floor UVs and provisional interior spans.\nOpen exits are not barriers. Falls reset automatically." % fixture.regions.size()
	if full_map:
		label.text = "Full recovered cave — experimental walk\n1,953 floors · complete extracted layout · walls and openings provisional\nWASD: move · Shift: sprint · Mouse: look · Esc: release · R: reset\nF: fly through geometry · Space/Ctrl: fly up/down · N/P: jump to checkpoint\nAmber: special links · Pink: unresolved materials · Objects and hazards incomplete."
func _show_shell_face(_points: Array) -> bool:
	return true
func _add_face(points: Array, material: Material, collision_faces: PackedVector3Array, uv: Array = []) -> void:
	var key := material.get_instance_id()
	var surface: SurfaceTool
	if surface_groups.has(key): surface = surface_groups[key]
	else:
		surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(material)
		surface_groups[key] = surface
	for index in [0, 1, 2, 0, 2, 3]:
		if not uv.is_empty(): surface.set_uv(Vector2(uv[index][0], uv[index][1]))
		var p := point(points[index])
		surface.add_vertex(p)
		collision_faces.append(p)
func _reset() -> void:
	waypoint = 0
	route_ticks = 0
	if connected and checkpoint < 0: target = point(fixtures[selected].waypoints[0])
	flying = false
	flight_label.text = "Walk mode"
	route_limit = int(Vector2(target.x - start.x, target.z - start.z).length() / WALK_SPEED * 60 * 4) + 240
	player.position = start + Vector3.UP * 34
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(target.x, player.position.y, target.z))
	camera.rotation.x = -0.15
	ticks = 0
	grounded = false
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.003)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.4, 1.4)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.keycode == KEY_R: _reset()
		if event.keycode == KEY_F and full_map:
			flying = not flying
			player.velocity = Vector3.ZERO
			flight_label.text = "Fly mode — collision bypassed" if flying else "Walk mode"

		if event.keycode in [KEY_N, KEY_P]:
			if full_map:
				_jump_checkpoint(checkpoint + (1 if event.keycode == KEY_N else -1))
			else:
				selected = posmod(selected + (1 if event.keycode == KEY_N else -1), fixtures.size())
				_load_pair()
func _jump_checkpoint(index: int) -> void:
	checkpoint = posmod(index, fixtures[0].checkpoints.size())
	var entry: Dictionary = fixtures[0].checkpoints[checkpoint]
	start = point(entry.start)
	target = point(entry.end)
	_reset()
	flight_label.text = "Walk mode · checkpoint %d · regions %s" % [checkpoint + 1, entry.regions]
func _physics_process(delta: float) -> void:
	if player == null: return
	ticks += 1
	route_ticks += 1
	var direction := Vector3.ZERO
	if smoke and grounded:
		direction = target - player.position
		direction.y = 0
		direction = direction.normalized()
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var input := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		direction = player.basis * input.normalized()
	var speed := SPRINT_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) or "--sprint-smoke" in OS.get_cmdline_user_args() else WALK_SPEED
	if smoke:
		var remaining := Vector2(target.x - player.position.x, target.z - player.position.z).length()
		speed = minf(speed, remaining / delta)
	if flying:
		direction = camera.global_basis * Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))) if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Vector3.ZERO
		direction.y += float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL))
		player.position += direction.normalized() * speed * 4 * delta
		return
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.velocity.y = 0 if player.is_on_floor() else player.velocity.y - 128 * delta
	player.move_and_slide()
	grounded = grounded or player.is_on_floor()
	var minimum_y: float = fixtures[0].minimum_floor_y if full_map else minf(start.y, target.y)
	if player.position.y < minimum_y - 256:
		resets += 1
		_reset()
	if smoke:
		var distance := Vector2(player.position.x - target.x, player.position.z - target.z).length()
		if grounded and distance < 1:
			if checkpoint_smoke:
				if checkpoint + 1 == fixtures[0].checkpoints.size():
					print("Full map: 119 checkpoint routes passed; resets=", resets)
					get_tree().quit(0 if resets == 0 else 1)
				else: _jump_checkpoint(checkpoint + 1)
				return
			if connected and waypoint + 1 < fixtures[selected].waypoints.size():
				waypoint += 1
				target = point(fixtures[selected].waypoints[waypoint])
				route_ticks = 0
				route_limit = int(Vector2(target.x - player.position.x, target.z - player.position.z).length() / WALK_SPEED * 60 * 4) + 240
				return
			completed += 1
			if completed == fixtures.size():
				print("Walk view smoke: ", completed, " areas reached; waypoints=", waypoint + 1, "; resets=", resets)
				get_tree().quit(0 if resets == 0 else 1)
			else:
				selected = (selected + 1) % fixtures.size()
				_load_pair()
		elif route_ticks > route_limit or resets > 0:
			push_error("Walk view failed at waypoint %d, position %s target %s" % [waypoint, player.position, target])
			get_tree().quit(1)
	if capture and ticks == 30:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_capture_path("") + ("full_walk_review.png" if full_map else ("connected_walk_review.png" if connected else "original_walk_review.png")))
		get_tree().quit()

func _capture_path(relative: String) -> String:
	# Exported demos store diagnostics in their writable user-data folder.
	var root := "res://captures/" if OS.has_feature("editor") else "user://captures/"
	var destination := root + relative
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	return destination
