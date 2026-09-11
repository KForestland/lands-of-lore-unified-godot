extends "res://scripts/lol2/textured_cave_review.gd"

const INDEX_ROOT := "res://assets/lol2/generated/wall_indices/"
var index_view: SubViewport
var index_camera: Camera3D
var resolve_surface: ColorRect
var capture_frames := 0

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

func _resize_index_view() -> void:
	index_view.size = get_window().size
	resolve_surface.size = Vector2(get_window().size)

func _process(_delta: float) -> void:
	if index_camera == null:
		return
	index_camera.global_transform = camera.global_transform
	if "--capture-indexed-walls" in OS.get_cmdline_user_args():
		capture_frames += 1
		if capture_frames == 20:
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(_capture_path(""))
			index_view.get_texture().get_image().save_png(_capture_path("cave_wall_indices.png"))
			get_viewport().get_texture().get_image().save_png(_capture_path("cave_wall_resolved.png"))
			get_tree().quit()
