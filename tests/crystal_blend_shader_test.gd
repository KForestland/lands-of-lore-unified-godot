extends SceneTree
## Isolated GPU implementation check of the recovered table rule, not native projection/shade parity.
func _initialize() -> void: run.call_deferred()
func encoded(index: int) -> Color:
	return Color(float(index % 16 * 12 + 64) / 255.0, float(index / 16 * 12 + 64) / 255.0, 0.0, 1.0)
func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(256, 128)
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := Image.create(256, 128, false, Image.FORMAT_RGB8)
	var source := Image.create(256, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 256:
			background.set_pixel(x, y, encoded(x))
			source.set_pixel(x, y, encoded(y))
	var table := Image.load_from_file("res://assets/lol2/generated/cave_stalagmite/blend_upper.png")
	var rect := ColorRect.new()
	rect.size = Vector2(256, 128)
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/lol2/indexed_remap_layer.gdshader")
	material.set_shader_parameter("background_indices", ImageTexture.create_from_image(background))
	material.set_shader_parameter("source_indices", ImageTexture.create_from_image(source))
	material.set_shader_parameter("blend_table", ImageTexture.create_from_image(table))
	material.set_shader_parameter("palette_blend", true)
	rect.material = material
	view.add_child(rect)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var actual := view.get_texture().get_image()
	for y in 128:
		for x in 256:
			var expected := encoded(x if y == 0 else int(round(table.get_pixel(x, y).r * 255.0)))
			var got := actual.get_pixel(x, y)
			if absf(got.r - expected.r) > 1.1 / 255.0 or absf(got.g - expected.g) > 1.1 / 255.0:
				push_error("Crystal GPU blend mismatch at %s: %s vs %s" % [Vector2i(x,y),got,expected])
				quit(1)
				return
	print("PASS crystal_blend_shader: all32768 source/destination combinations match original upper table; source0 preserves background")
	quit(0)
