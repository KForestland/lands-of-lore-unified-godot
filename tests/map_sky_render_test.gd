extends SceneTree
## Production camera controller + sky shader, including wrap and top-fill.
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var pixels := Image.create(1280, 300, false, Image.FORMAT_R8)
	for y in 300:
		for x in 1280:
			pixels.set_pixel(x, y, Color(float((x + y * 7) % 256) / 255.0, 0, 0))
	var view := SubViewport.new()
	view.size = Vector2i(640,400)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_SKY
	world.environment.sky = Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/lol2/all_maps_sky.gdshader")
	material.set_shader_parameter("indexed", true)
	material.set_shader_parameter("native_projection", true)
	material.set_shader_parameter("panorama_indices", ImageTexture.create_from_image(pixels))
	world.environment.sky.sky_material = material
	view.add_child(world)
	var cam := Camera3D.new()
	view.add_child(cam)
	var checks := 0
	for settings in [Vector2(0,50), Vector2(29888,50), Vector2(60672,60), Vector2(65535,100), Vector2(100,250), Vector2(49152,-100)]:
		cam.rotation.y = -settings.x * TAU / 65536.0
		material.set_shader_parameter("vertical_origin", settings.y)
		preload("res://scripts/lol2/map_sky_controller.gd").update_sky(world.environment, cam)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered := view.get_texture().get_image()
		for y in [0,1,79,200,399]:
			for x in [0,1,319,638,639]:
				var sx := posmod(floori(settings.x * 1280.0 / 65536.0 + 0.25 + x * 0.5),1280)
				var sy := floori(200.0 - settings.y + y * 0.5)
				if sy < 0: sx = 0
				sy = clampi(sy,0,299)
				var expected := (sx + sy*7) % 256
				var color := rendered.get_pixel(x,y)
				var actual := roundi((color.r*255.0-64.0)/12.0) + 16*roundi((color.g*255.0-64.0)/12.0)
				checks += 1
				if actual != expected:
					failures += 1
					print("FAIL sky ",settings," pixel ",x,",",y," got ",actual," expected ",expected)
	print("Production sky shader: ", "PASS" if failures == 0 else "FAIL", " ",checks," samples; ",failures," failures")
	view.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
