extends SceneTree
## Tests the shared source shade path and localized toggle in both renderers.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print("PASS " if value else "FAIL ", message)
	if not value: failures += 1
func shot(view: SubViewport) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func run() -> void:
	var shade := Image.load_from_file("/home/bob/lol2_out/all_maps_20260922/L14_HT/environment/shade_indices.png")
	var palette := Image.load_from_file("/home/bob/lol2_out/all_maps_20260922/L14_HT/environment/palette_dac.png")
	var chosen := 0
	for index in range(2, 256):
		if shade.get_pixel(index, 10).r != shade.get_pixel(index, 63).r:
			chosen = index
			break
	check(chosen > 0, "fixture selects a texel changed by native shade rows")
	var indices := Image.create(1, 1, false, Image.FORMAT_R8)
	indices.fill(Color(float(chosen)/255.0, 0, 0))
	for indexed in [false, true]:
		var view := SubViewport.new()
		view.size = Vector2i(128, 64)
		view.own_world_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 100
		cam.far = 1000
		cam.cull_mask = 1
		view.add_child(cam)
		var controller = preload("res://scripts/lol2/map_light_controller.gd").new()
		view.add_child(controller)
		for near in [true, false]:
			var material := ShaderMaterial.new()
			material.shader = preload("res://scripts/lol2/all_maps_indexed_surface.gdshader") if indexed else preload("res://scripts/lol2/all_maps_lit_surface.gdshader")
			material.set_shader_parameter("indices", ImageTexture.create_from_image(indices))
			material.set_shader_parameter("palette", ImageTexture.create_from_image(palette))
			material.set_shader_parameter("shade_table", ImageTexture.create_from_image(shade))
			material.set_shader_parameter("source_lighting", true)
			material.set_shader_parameter("use_vertex_light", false)
			material.set_shader_parameter("sector_light", Vector4(10, 9999, 9999, 128))
			controller.materials.append(material)
			var mesh := QuadMesh.new()
			mesh.size = Vector2(40, 40)
			mesh.material = material
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			instance.position = Vector3(-25 if near else 25, 0, -25 if near else -400)
			view.add_child(instance)
		var off := await shot(view)
		controller.enabled = true
		var on := await shot(view)
		controller.enabled = false
		var restored := await shot(view)
		var label := "indexed" if indexed else "RGB"
		check(off.get_pixel(48,32) != on.get_pixel(48,32), label + " nearby surface brightens")
		check(off.get_pixel(80,32) == on.get_pixel(80,32), label + " distant surface unchanged")
		check(off.get_data() == restored.get_data(), label + " disabling light restores every pixel")
		if indexed:
			var expected := roundi(shade.get_pixel(chosen, 10).r * 255.0)
			var pixel := off.get_pixel(48,32)
			var actual := roundi((pixel.r*255.0-64.0)/12.0) + 16*roundi((pixel.g*255.0-64.0)/12.0)
			check(actual == expected, "indexed dark texel equals source shade table")
		view.queue_free()
		await process_frame
	print("Light rendering: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
