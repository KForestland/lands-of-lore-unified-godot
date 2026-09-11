extends Node2D

var remap_material: ShaderMaterial

func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	get_window().content_scale_factor = 1.0
	get_window().size = Vector2i(640, 400)
	get_window().title = "Sprite remap test — candidate shade64 (unverified binding) · Space: toggle"
	remap_material = ShaderMaterial.new()
	remap_material.shader = load("res://scripts/lol2/special_pixel_review.gdshader")
	for item in [["background_indices", "background"], ["sprite_indices", "sprite"], ["palette", "palette"], ["destination_remap", "remap"]]:
		var image := Image.load_from_file("res://assets/lol2/generated/special_pixel_review/%s.png" % item[1])
		if image == null or image.is_empty():
			push_error("Build the special pixel fixture first")
			get_tree().quit(1)
			return
		remap_material.set_shader_parameter(item[0], ImageTexture.create_from_image(image))
	var surface := ColorRect.new()
	surface.size = Vector2(640, 400)
	surface.material = remap_material
	add_child(surface)
	if "--capture-remap" in OS.get_cmdline_user_args():
		for frame in range(5):
			await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://captures")
		get_viewport().get_texture().get_image().save_png("res://captures/special_pixel_review.png")
		get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		remap_material.set_shader_parameter("apply_remap", not remap_material.get_shader_parameter("apply_remap"))
