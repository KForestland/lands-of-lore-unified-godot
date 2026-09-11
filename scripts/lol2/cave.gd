extends Node3D
## Authored test geometry. No claim of an extracted Draracle level.
const Player = preload("res://scripts/lol2/cave_player.gd")
const TEXTURE_PATH = "res://assets/lol2/generated/cave_material/rock.png"
# Center X, longitudinal Z, half-width, ceiling height.
const SECTIONS = [Vector4(0, 2, 3, 4), Vector4(0, -4, 4, 5), Vector4(1, -10, 4.5, 5.5), Vector4(2, -16, 2, 3), Vector4(4, -22, 1.8, 3), Vector4(5, -28, 4.5, 6), Vector4(4, -34, 5, 6), Vector4(1, -40, 3, 4), Vector4(-2, -46, 1.8, 3), Vector4(-3, -52, 3.8, 5), Vector4(-2, -58, 4, 5), Vector4(0, -64, 2, 3), Vector4(0, -68, 2, 3)]
var player: CharacterBody3D
var rock: StandardMaterial3D
var status: Label
var completed := false
var reference_mode := false
var smoke := false
var elapsed := 0.0
var waypoint := 1
var wall_check := false
var capture_frames := 0

func _ready() -> void:
	smoke = "--cave-smoke" in OS.get_cmdline_user_args()
	var capture := "--cave-capture" in OS.get_cmdline_user_args()
	rock = StandardMaterial3D.new()
	rock.cull_mode = BaseMaterial3D.CULL_DISABLED
	rock.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	rock.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if ResourceLoader.exists(TEXTURE_PATH):
		var source_texture := load(TEXTURE_PATH) as Texture2D
		var source_image := source_texture.get_image()
		source_image.generate_mipmaps()
		rock.albedo_texture = ImageTexture.create_from_image(source_image)
	else:
		push_error("Cave rock missing. Run tools/lol2/import_cave_material.py first.")
		if smoke:
			get_tree().quit(1)
			return
		rock.albedo_color = Color(0.45, 0.45, 0.45)
	_build_cave()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.035, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.7)
	env.ambient_light_energy = 0.65
	environment.environment = env
	add_child(environment)
	for i in [1, 5, 9, 11]:
		var light := OmniLight3D.new()
		light.position = Vector3(SECTIONS[i].x, 2.3, SECTIONS[i].y)
		light.omni_range = 12.0
		light.light_energy = 1.8
		light.light_color = Color(1.0, 0.77, 0.48) if i != 11 else Color(0.35, 0.8, 1.0)
		add_child(light)
	player = Player.new()
	player.automated = smoke or capture
	player.position = Vector3(0, 0.08, 0)
	add_child(player)
	player.auto_target = Vector3(SECTIONS[1].x, 0, SECTIONS[1].y)
	var exit_marker := MeshInstance3D.new()
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(1.2, 2.2, 0.15)
	exit_marker.mesh = marker_mesh
	exit_marker.position = Vector3(0, 1.1, -66.5)
	var marker_material := StandardMaterial3D.new()
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_material.albedo_color = Color(0.3, 0.85, 0.95)
	exit_marker.material_override = marker_material
	add_child(exit_marker)
	var ui := CanvasLayer.new()
	add_child(ui)
	status = Label.new()
	status.position = Vector2(22, 18)
	status.add_theme_color_override("font_shadow_color", Color.BLACK)
	status.add_theme_constant_override("shadow_offset_x", 2)
	status.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(status)
	_update_status()
	if capture:
		capture_frames = 1

func _ring(s: Vector4) -> Array[Vector3]:
	return [Vector3(s.x-s.z, 0, s.y), Vector3(s.x-s.z, s.w*0.5, s.y), Vector3(s.x-s.z*0.65, s.w*0.88, s.y), Vector3(s.x, s.w, s.y), Vector3(s.x+s.z*0.7, s.w*0.85, s.y), Vector3(s.x+s.z, s.w*0.45, s.y), Vector3(s.x+s.z, 0, s.y)]

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)

func _build_cave() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(SECTIONS.size()-1):
		var a := _ring(SECTIONS[i])
		var b := _ring(SECTIONS[i+1])
		var perimeter := 0.0
		for j in range(a.size()):
			var k := (j+1) % a.size()
			var length := a[j].distance_to(a[k])
			var uv0 := Vector2(perimeter/2, -SECTIONS[i].y/2)
			var uv1 := Vector2((perimeter+length)/2, -SECTIONS[i].y/2)
			var uv2 := Vector2((perimeter+length)/2, -SECTIONS[i+1].y/2)
			var uv3 := Vector2(perimeter/2, -SECTIONS[i+1].y/2)
			_triangle(st, a[j], a[k], b[k], uv0, uv1, uv2)
			_triangle(st, a[j], b[k], b[j], uv0, uv2, uv3)
			perimeter += length
	for index in [0, SECTIONS.size()-1]:
		var ring := _ring(SECTIONS[index])
		for j in range(1, ring.size()-1):
			_triangle(st, ring[0], ring[j], ring[j+1], Vector2(ring[0].x, ring[0].y), Vector2(ring[j].x, ring[j].y), Vector2(ring[j+1].x, ring[j+1].y))
	st.generate_normals()
	var mesh := st.commit()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = rock
	add_child(instance)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
		if event.keycode == KEY_F:
			reference_mode = not reference_mode
			rock.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if reference_mode else BaseMaterial3D.SHADING_MODE_PER_PIXEL
			_update_status()

func _update_status() -> void:
	status.text = "CAVE STUDY 01  |  Lands of Lore II — test layout
WASD move · Mouse look · Esc release mouse · R restart · F lighting
%s
%s" % ["Fixed original shade colour" if reference_mode else "Prototype lighting", "Exit reached — cave route complete. R to restart." if completed else "Follow the chambers to the blue exit."]

func _physics_process(delta: float) -> void:
	if player == null:
		return
	elapsed += delta
	if player.position.y < -3:
		_fail("Player fell through cave floor")
		return
	if player.position.z < -65 and not completed:
		completed = true
		_update_status()
		if smoke:
			print("CAVE_SMOKE_PASS: wall collision, floor support, chamber route and exit verified")
			get_tree().quit()
	if smoke:
		if not wall_check and elapsed > 0.3:
			wall_check = true
			var blocked := player.test_move(player.global_transform, Vector3(20, 0, 0))
			if not blocked or not player.is_on_floor():
				_fail("Wall collision or initial floor support failed")
				return
		if waypoint < SECTIONS.size()-1 and player.position.distance_to(player.auto_target) < 0.35:
			waypoint += 1
			player.auto_target = Vector3(SECTIONS[waypoint].x, 0, SECTIONS[waypoint].y)
		if elapsed > 35:
			_fail("Route timed out at " + str(player.position))
	if capture_frames > 0:
		capture_frames += 1
		if capture_frames == 20:
			_capture.call_deferred()

func _capture() -> void:
	await RenderingServer.frame_post_draw
	var path := "res://captures/cave_first_room.png"
	DirAccess.make_dir_recursive_absolute("res://captures")
	get_viewport().get_texture().get_image().save_png(path)
	print("CAVE_CAPTURE: " + path)
	get_tree().quit()

func _fail(message: String) -> void:
	push_error(message)
	if smoke:
		get_tree().quit(1)
	else:
		player.position = Vector3(0, 0.08, 0)
		player.velocity = Vector3.ZERO
