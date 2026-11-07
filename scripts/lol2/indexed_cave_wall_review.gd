extends "res://scripts/lol2/textured_cave_review.gd"

const INDEX_ROOT := "res://assets/lol2/generated/wall_indices/"
## Indexed targets stay at most 1920x1080. The resolve rect still fills the window.
const INDEX_MAX_SIZE := Vector2i(1920, 1080)
var index_view: SubViewport
var index_camera: Camera3D
var resolve_surface: ColorRect
var capture_frames := 0
const ClassicShading = preload("res://scripts/lol2/classic_depth_shading.gd")
var classic_shading: ClassicShading

## Classic depth shading sectors (region -> ambient, fade start, span); loaded on first use during the build.
func _region_light(region: int) -> Color:
	if classic_shading == null:
		classic_shading = ClassicShading.new()
		if not classic_shading.load_area("L1_DC"): classic_shading.regions = {}
	return classic_shading.sector(region)

func _exit_tree() -> void:
	ClassicShading.clear()

func _ready() -> void:
	super._ready()
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(960, 540)
	get_window().title = "Indexed cavern walls — diagnostic · WASD / mouse · N/P checkpoints"
	for key in wall_materials:
		var descriptor := int(str(key).get_slice("_", 0))
		var mode := int(str(key).get_slice("_", 1))
		var image := Image.load_from_file(INDEX_ROOT + "material_%d.png" % descriptor)
		if image == null or image.is_empty():
			push_error("Build indexed wall textures first")
			get_tree().quit(1)
			return
		var material: ShaderMaterial = wall_materials[key]
		material.shader = load("res://scripts/lol2/indexed_wall_review.gdshader")
		material.set_shader_parameter("wall_indices", ImageTexture.create_from_image(image))
		material.set_shader_parameter("address_mode", mode)
	for child in native_walls.get_children():
		child.layers = 2
	index_view = SubViewport.new()
	index_view.size = Vector2i(960, 540)
	index_view.world_3d = get_world_3d()
	index_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	index_view.msaa_3d = Viewport.MSAA_DISABLED
	add_child(index_view)
	index_camera = Camera3D.new()
	index_camera.cull_mask = 2
	index_camera.fov = camera.fov
	index_camera.near = camera.near
	index_camera.far = camera.far
	index_view.add_child(index_camera)
	_configure_cave_sky()
	index_camera.current = true
	index_camera.global_transform = camera.global_transform
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)
	resolve_surface = ColorRect.new()
	resolve_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resolve_surface.size = Vector2(960, 540)
	var resolve := ShaderMaterial.new()
	resolve.shader = load("res://scripts/lol2/indexed_wall_resolve.gdshader")
	resolve.set_shader_parameter("packed_wall_indices", index_view.get_texture())
	resolve.set_shader_parameter("palette", ImageTexture.create_from_image(Image.load_from_file(INDEX_ROOT + "palette.png")))
	resolve_surface.material = resolve
	overlay.add_child(resolve_surface)
	get_window().size_changed.connect(_resize_index_view)
	print("Indexed cave wall review: %d spans, %d material/address groups; walls only" % [wall_count, wall_materials.size()])

func _bounded_index_size(window_size: Vector2i) -> Vector2i:
	if window_size.x <= INDEX_MAX_SIZE.x and window_size.y <= INDEX_MAX_SIZE.y:
		return window_size
	# Whole-number divisor: the nearest-filtered resolve then gives every index pixel the same screen size. A
	# fractional scale (6144 wide -> 1920 is 3.2x) makes texels alternate between 3 and 4 pixels as the view moves.
	var divisor := maxi(ceili(float(window_size.x) / float(INDEX_MAX_SIZE.x)), ceili(float(window_size.y) / float(INDEX_MAX_SIZE.y)))
	return Vector2i(maxi(1, int(round(float(window_size.x) / divisor))), maxi(1, int(round(float(window_size.y) / divisor))))

func _resize_index_view() -> void:
	var window_size := get_window().size
	index_view.size = _bounded_index_size(window_size)
	resolve_surface.size = Vector2(window_size)

func _process(_delta: float) -> void:
	if index_camera == null:
		return
	index_camera.global_transform = camera.global_transform
	if classic_shading != null: classic_shading.update_view(camera.global_position - wall_translation)
	if "--capture-indexed-walls" in OS.get_cmdline_user_args():
		capture_frames += 1
		if capture_frames == 20:
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(_capture_path(""))
			index_view.get_texture().get_image().save_png(_capture_path("cave_wall_indices.png"))
			get_viewport().get_texture().get_image().save_png(_capture_path("cave_wall_resolved.png"))
			get_tree().quit()

func _configure_cave_sky() -> void:
	var root := "res://assets/lol2/generated/cave_sky/"
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root + "environment.json"))
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://scripts/lol2/all_maps_sky.gdshader")
	sky_material.set_shader_parameter("panorama", ImageTexture.create_from_image(Image.load_from_file(root + "panorama.png")))
	sky_material.set_shader_parameter("panorama_indices", ImageTexture.create_from_image(Image.load_from_file(root + "panorama_indices.png")))
	sky_material.set_shader_parameter("indexed", true)
	sky_material.set_shader_parameter("native_projection", true)
	sky_material.set_shader_parameter("vertical_origin", float(metadata.panorama.vertical_origin))
	var sky := Sky.new()
	sky.sky_material = sky_material
	var world := WorldEnvironment.new()
	world.name = "CaveSkyEnvironment"
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_SKY
	world.environment.sky = sky
	# Camera override keeps the indexed sky out of isolated sprite mask passes.
	index_camera.environment = world.environment
	index_camera.add_child(world)
	var controller = preload("res://scripts/lol2/map_sky_controller.gd").new()
	controller.environment_path = NodePath("../CaveSkyEnvironment")
	controller.camera_override = index_camera
	index_camera.add_child(controller)
