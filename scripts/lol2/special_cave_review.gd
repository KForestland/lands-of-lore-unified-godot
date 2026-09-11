extends "res://scripts/lol2/indexed_complete_cave_review.gd"

const SPECIAL_ROOT := "res://assets/lol2/generated/special_cave_review/"
var layer_views: Array[SubViewport] = []
var composites: Array[SubViewport] = []
var layer_cameras: Array[Camera3D] = []
var special_frames := 0
var raw_views: Array[SubViewport] = []

func _copy_occluders(node: Node) -> void:
	if node is MeshInstance3D and node.layers == 2:
		var original: MeshInstance3D = node
		var duplicate := MeshInstance3D.new()
		duplicate.mesh = original.mesh
		duplicate.layers = 4
		var material: Material = original.material_override if original.material_override != null else original.mesh.surface_get_material(0)
		var mask: ShaderMaterial = material.duplicate()
		mask.set_shader_parameter("mask_capture", true)
		duplicate.material_override = mask
		add_child(duplicate)
		duplicate.global_transform = original.global_transform
	for child in node.get_children():
		_copy_occluders(child)

func _plane(distance: float, extent: Vector2, offset: Vector2, layer: int, texture: Texture2D) -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/lol2/indexed_surface_review.gdshader")
	material.set_shader_parameter("indices", texture)
	# Pixel0 writes an empty source index in this isolated layer. Static
	# occluders in front overwrite it through normal depth testing.
	var quad := QuadMesh.new()
	quad.size = extent
	quad.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.layers = layer
	add_child(mesh)
	mesh.global_transform = camera.global_transform
	mesh.global_position += camera.global_basis * Vector3(offset.x, offset.y, -distance)

func _source_view(layer: int, occlusion: bool = true) -> SubViewport:
	var view := SubViewport.new()
	view.size = index_view.size
	view.world_3d = get_world_3d()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var cam := Camera3D.new()
	cam.cull_mask = (4 if occlusion else 0) | layer
	cam.fov = camera.fov
	cam.near = camera.near
	cam.far = camera.far
	cam.environment = Environment.new()
	cam.environment.background_mode = Environment.BG_COLOR
	cam.environment.background_color = Color.BLACK
	view.add_child(cam)
	cam.current = true
	cam.global_transform = camera.global_transform
	layer_cameras.append(cam)
	if occlusion: layer_views.append(view)
	else: raw_views.append(view)
	return view

func _compose(background: Texture2D, source: Texture2D) -> SubViewport:
	var view := SubViewport.new()
	view.size = index_view.size
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var surface := ColorRect.new()
	surface.size = Vector2(view.size)
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/lol2/indexed_remap_layer.gdshader")
	material.set_shader_parameter("background_indices", background)
	material.set_shader_parameter("source_indices", source)
	material.set_shader_parameter("remap", ImageTexture.create_from_image(Image.load_from_file(SPECIAL_ROOT + "remap.png")))
	surface.material = material
	view.add_child(surface)
	composites.append(view)
	return view

func _ready() -> void:
	super._ready()
	get_window().title = "Cave remap diagnostic — two test sprites, fixed camera"
	set_physics_process(false)
	set_process_unhandled_input(false)
	_copy_occluders(stage)
	var texture := ImageTexture.create_from_image(Image.load_from_file(SPECIAL_ROOT + "sprite_474.png"))
	# Equal angular size provides both repeated remaps and ordinary overlap.
	_plane(36, Vector2(36, 24), Vector2.ZERO, 8, texture)
	_plane(24, Vector2(24, 16), Vector2(1.2, 0), 16, texture)
	# Explicit near and between-layer blockers exercise known depth ordering.
	for specification in [[18.0, Vector2(4, 8), Vector2(-5, 0), 42], [30.0, Vector2(4, 10), Vector2(5, 0), 19]]:
		for mask in [false, true]:
			var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
			var value: float = 0.0 if mask else float(specification[3]) / 255.0
			image.fill(Color(value, value, value))
			_plane(specification[0], specification[1], specification[2], 4 if mask else 2, ImageTexture.create_from_image(image))
	_source_view(8, false)
	_source_view(16, false)
	var far_view := _source_view(8)
	var near_view := _source_view(16)
	var first := _compose(index_view.get_texture(), far_view.get_texture())
	var second := _compose(first.get_texture(), near_view.get_texture())
	resolve_surface.material.set_shader_parameter("packed_wall_indices", second.get_texture())
	print("Two diagnostic resource474 layers, ordered far-to-near; placements are not native")

func _process(_delta: float) -> void:
	if layer_views.size() != 2:
		return
	special_frames += 1
	if special_frames == 25 and "--capture-special-cave" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://captures/special_cave")
		index_view.get_texture().get_image().save_png("res://captures/special_cave/background.png")
		for i in range(2):
			layer_views[i].get_texture().get_image().save_png("res://captures/special_cave/source%d.png" % i)
			raw_views[i].get_texture().get_image().save_png("res://captures/special_cave/raw%d.png" % i)
			composites[i].get_texture().get_image().save_png("res://captures/special_cave/composite%d.png" % i)
		get_viewport().get_texture().get_image().save_png("res://captures/special_cave/resolved.png")
		get_tree().quit()
