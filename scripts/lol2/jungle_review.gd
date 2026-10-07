extends Node3D
## Source jungle geometry review. Not connected to the normal walkthrough.
const ROOT := "res://assets/lol2/generated/jungle_review/"
@export var geometry_file := ROOT + "jungle.json"
## Wall faces with no source wall record (no bound texture) stay collision but may be left undrawn.
## The original renders walls per wall record, so an edge without one shows nothing (Jungle: ~1385 faces).
var draw_unbound_walls := true
@export var review_title := "Huline Jungle"
var player: CharacterBody3D
var camera: Camera3D
var start := Vector3.ZERO
var ready_for_review := false
var face_count := 0
var flying := false
var jump_requested := false
var resets := 0
var fall_reset_height := -2048.0
var development_mode := true
var development_overlay: CanvasLayer
var materials: Dictionary = {}
var dynamic_floor_regions: Array[int] = []
var surface_animation: Node

func _ready() -> void:
	# Authored replacement sky; source terrain colors stay unshaded.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("487f9d")
	sky_material.sky_horizon_color = Color("c8d5c4")
	sky_material.ground_horizon_color = Color("c8d5c4")
	sky_material.ground_bottom_color = Color("69795e")
	sky_material.sky_curve = 0.18
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(geometry_file))
	start = Vector3(data.start[0], data.start[1], data.start[2])
	# Recovery must be below every authored floor, including the lower Hive.
	# The 512-unit void margin is an adapter, not native fall-damage behavior.
	for face in data.faces:
		if face.kind == "floor":
			for point in face.points:
				fall_reset_height = minf(fall_reset_height,float(point[1])-512.0)
	var groups: Dictionary = {}
	var collision := PackedVector3Array()
	for face in data.faces:
		if not include_static_face(face): continue
		var key: String = face.get("material",face.kind)
		if not groups.has(key):
			var mat := StandardMaterial3D.new()
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			if data.materials.has(key):
				mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(geometry_file.get_base_dir() + "/" + data.materials[key]))
				if key in data.get("alpha_cutout_materials", []):
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					mat.alpha_scissor_threshold = 0.5
			else:
				mat.albedo_color = Color(0.24, 0.32, 0.25) if key == "floor" else Color(0.32, 0.34, 0.31)
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
	for key in groups:
		var surface: SurfaceTool = groups[key]
		if key == "wall" and not data.materials.has("wall") and not draw_unbound_walls: continue
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		add_child(mesh)
	if not data.get("animations", {}).is_empty():
		surface_animation = preload("res://scripts/lol2/surface_animation.gd").new()
		surface_animation.configure(materials, data.animations, geometry_file.get_base_dir() + "/")
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
	var canvas := CanvasLayer.new()
	development_overlay = canvas
	add_child(canvas)
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.text = review_title + " — geometry review\nWASD: walk · Mouse: look · F: fly · R: reset · Esc: release mouse\nSource terrain and supported textures. Objects and gameplay pending."
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	get_window().title = "Lands of Lore II — Jungle geometry review"
	if not "--jungle-test" in OS.get_cmdline_user_args(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ready_for_review = true

func set_development_mode(enabled: bool) -> void:
	development_mode = enabled
	if is_instance_valid(development_overlay): development_overlay.visible = enabled
	if not enabled:
		flying = false
		player.velocity = Vector3.ZERO

func reset_position() -> void:
	jump_requested = false
	player.position = start
	player.velocity = Vector3.ZERO
	# Temporary review direction; native heading conversion remains unverified.
	player.rotation = Vector3(0, -PI / 2, 0)
	camera.rotation = Vector3.ZERO
	flying = false

func _unhandled_input(event: InputEvent) -> void:
	if "--jungle-test" in OS.get_cmdline_user_args(): return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.003)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.4, 1.4)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.keycode == KEY_SPACE and request_jump():
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F3:
			set_development_mode(not development_mode)
			return
		if not development_mode: return
		if event.keycode == KEY_R: reset_position()
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
	move_grounded(direction,delta,Input.is_physical_key_pressed(KEY_SHIFT))

func request_jump() -> bool:
	if jump_requested or flying or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not player.is_on_floor(): return false
	var warriors = get_node_or_null("Warriors")
	if warriors != null and warriors.health == 0: return false
	jump_requested = true
	return true

func move_grounded(direction: Vector3, delta: float, sprint: bool = false) -> void:
	# Shared by player input and bounded traversal acceptance tests.
	var speed := 120.0 if sprint else 80.0
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	var jumping := jump_requested and player.is_on_floor()
	jump_requested = false
	player.velocity.y = 200.0 if jumping else (0.0 if player.is_on_floor() else player.velocity.y - 320 * delta)
	if not jumping and player.velocity.y <= 0 and preload("res://scripts/lol2/walk_step.gd").try_step(player,Vector3(player.velocity.x,0,player.velocity.z)*delta):
		player.velocity.x = 0
		player.velocity.z = 0
	player.move_and_slide()
	if player.position.y < fall_reset_height:
		resets += 1
		reset_position()

func include_static_face(face: Dictionary) -> bool:
	return not (face.kind == "floor" and int(face.region) in dynamic_floor_regions)
