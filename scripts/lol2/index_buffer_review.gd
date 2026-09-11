extends Node2D

const FIXTURE := "res://assets/lol2/generated/special_pixel_review/"
var background_view: SubViewport
var source_view: SubViewport

func _texture(name: String) -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file(FIXTURE + name + ".png"))

func _quad(view: SubViewport, rect: Rect2, depth: float, texture_name: String, index: int = -1) -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/lol2/index_buffer_review.gdshader")
	material.set_shader_parameter("solid", index >= 0)
	material.set_shader_parameter("solid_index", float(maxi(index, 0)))
	material.set_shader_parameter("indices", _texture(texture_name))
	var mesh := QuadMesh.new()
	mesh.size = rect.size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(rect.get_center().x - 320, 200 - rect.get_center().y, depth)
	view.add_child(instance)

func _view(mask: bool) -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(640, 400)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_3d = Viewport.MSAA_DISABLED
	add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 400
	camera.position.z = 10
	camera.near = 0.1
	camera.far = 20
	view.add_child(camera)
	camera.current = true
	_quad(view, Rect2(0, 0, 640, 400), 0, "background", 0 if mask else -1)
	if mask:
		_quad(view, Rect2(0, 0, 640, 400), 0.5, "sprite")
	# Add in reverse depth order to ensure depth, not submission order, wins.
	_quad(view, Rect2(230, 120, 80, 140), 1, "background", 0 if mask else 7)
	_quad(view, Rect2(180, 80, 80, 120), 0.25, "background", 0 if mask else 19)
	return view

func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(640, 400)
	get_window().title = "Indexed 3D depth review — initial shade64"
	background_view = _view(false)
	source_view = _view(true)
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/lol2/special_pixel_review.gdshader")
	material.set_shader_parameter("packed_indices", true)
	material.set_shader_parameter("background_indices", background_view.get_texture())
	material.set_shader_parameter("sprite_indices", source_view.get_texture())
	material.set_shader_parameter("palette", _texture("palette"))
	material.set_shader_parameter("destination_remap", _texture("remap"))
	var surface := ColorRect.new()
	surface.size = Vector2(640, 400)
	surface.material = material
	add_child(surface)
	if "--capture-indices" in OS.get_cmdline_user_args():
		for frame in range(8):
			await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://captures")
		background_view.get_texture().get_image().save_png("res://captures/index_background.png")
		source_view.get_texture().get_image().save_png("res://captures/index_source.png")
		get_viewport().get_texture().get_image().save_png("res://captures/index_resolved.png")
		get_tree().quit()
