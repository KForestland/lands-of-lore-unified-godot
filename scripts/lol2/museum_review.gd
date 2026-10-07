extends Node3D
## Development review only; not connected to the cavern exit.
const ROOT := "res://assets/lol2/generated/museum_review/"
var player: CharacterBody3D
var camera: Camera3D
var start := Vector3.ZERO
var ready_for_review := false
var face_count := 0
var flying := false
var resets := 0
var museum_props: Node3D
var sword_transfer: Node3D
var museum_gate: Node3D
var sword_table: StaticBody3D
var development_mode := true
var development_overlay: CanvasLayer
var materials: Dictionary = {}
var surface_animation: Node

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "museum.json"))
	start = Vector3(data.start[0], data.start[1], data.start[2])
	var groups: Dictionary = {}
	var collision := PackedVector3Array()
	for face in data.faces:
		var key: String = face.material
		if not groups.has(key):
			var mat := StandardMaterial3D.new()
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			if data.materials.has(key):
				mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(ROOT + data.materials[key]))
			else:
				mat.albedo_color = Color(0.28, 0.31, 0.35) if key == "shell" else Color(0.65, 0.2, 0.55)
			materials[key] = mat
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(mat)
			groups[key] = surface
		var surface: SurfaceTool = groups[key]
		for i in [0, 1, 2, 0, 2, 3]:
			var p: Array = face.points[i]
			var vertex := Vector3(p[0], p[1], p[2])
			if face.has("uv"):
				surface.set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
			else:
				surface.set_uv(Vector2.ZERO)
			surface.add_vertex(vertex)
			collision.append(vertex)
		face_count += 1
	for surface in groups.values():
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		add_child(mesh)
	surface_animation = preload("res://scripts/lol2/surface_animation.gd").new()
	surface_animation.configure(materials, data.get("animations", {}), ROOT)
	add_child(surface_animation)
	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(collision)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	player = CharacterBody3D.new()
	player.safe_margin = 0.05
	player.floor_snap_length = 4
	var capsule := CapsuleShape3D.new()
	capsule.radius = 8
	capsule.height = 64
	var player_shape := CollisionShape3D.new()
	player_shape.shape = capsule
	player.add_child(player_shape)
	add_child(player)
	camera = Camera3D.new()
	camera.position.y = 24
	camera.near = 0.5
	camera.far = 20000
	player.add_child(camera)
	camera.current = true
	reset_position()
	museum_props = preload("res://scripts/lol2/museum_props.gd").new()
	add_child(museum_props)
	sword_transfer = preload("res://scripts/lol2/museum_sword_transfer.gd").new()
	sword_transfer.observer = camera
	sword_transfer.player = player
	add_child(sword_transfer)
	sword_table = preload("res://scripts/lol2/museum_sword_table.gd").new()
	add_child(sword_table)
	museum_gate = preload("res://scripts/lol2/museum_gate.gd").new()
	add_child(museum_gate)
	sword_transfer.sequence_finished.connect(museum_gate.open)
	sword_transfer.sequence_restarted.connect(museum_gate.reset)
	var canvas := CanvasLayer.new()
	development_overlay = canvas
	add_child(canvas)
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.text = "Draracle museum — development review\nWASD: walk · Mouse: look · Esc: release · Click: capture · R: reset · F: fly · G: props · T: sword sequence · F3: development mode\nSaved arrival XY · provisional view direction, wall/floor UVs and collision\nUnresolved walls/ceilings remain neutral · static prop subset · doors and scripts incomplete"
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	get_window().title = "Lands of Lore II — Museum development review"
	if not "--museum-test" in OS.get_cmdline_user_args(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ready_for_review = true

func set_development_mode(enabled: bool) -> void:
	development_mode = enabled
	if is_instance_valid(development_overlay): development_overlay.visible = enabled
	if not enabled:
		flying = false
		player.velocity = Vector3.ZERO
		museum_props.visible = true

func reset_position() -> void:
	player.position = start
	player.velocity = Vector3.ZERO
	# Diagnostic direction along +native X toward the adjacent passage; saved heading unverified.
	player.rotation = Vector3(0, -PI / 2, 0)
	camera.rotation = Vector3.ZERO
	flying = false

func _unhandled_input(event: InputEvent) -> void:
	if "--museum-test" in OS.get_cmdline_user_args(): return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.003)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.4, 1.4)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.keycode == KEY_F3:
			set_development_mode(not development_mode)
			return
		if not development_mode: return
		if event.keycode == KEY_R: reset_position()
		if event.keycode == KEY_T: sword_transfer.restart()
		if event.keycode == KEY_G: museum_props.visible = not museum_props.visible
		if event.keycode == KEY_F:
			flying = not flying
			player.velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if not ready_for_review: return
	var direction := Vector3.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var axis := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		direction = (player.basis * axis).normalized()
		if flying: direction.y = float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL))
	if flying:
		player.position += direction * 160 * delta
		return
	player.velocity.x = direction.x * 80
	player.velocity.z = direction.z * 80
	player.velocity.y = 0 if player.is_on_floor() else player.velocity.y - 320 * delta
	if preload("res://scripts/lol2/walk_step.gd").try_step(player,Vector3(player.velocity.x,0,player.velocity.z)*delta):
		player.velocity.x = 0
		player.velocity.z = 0
	player.move_and_slide()
	if player.position.y < -2048:
		resets += 1
		reset_position()
