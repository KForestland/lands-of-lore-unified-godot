extends SceneTree
func _initialize() -> void: run.call_deferred()
func viewport_for(world: World3D, mask: int) -> SubViewport:
	var view := SubViewport.new()
	view.size = Vector2i(128,128); view.world_3d = world
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera := Camera3D.new()
	camera.cull_mask = mask; camera.far = 30000.0
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_COLOR
	camera.environment.background_color = Color.BLACK
	view.add_child(camera); camera.current = true
	return view
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var depth := viewport_for(world.get_world_3d(),4|16384)
	var source := viewport_for(world.get_world_3d(),128|32768)
	var pixel := Image.create(1,1,false,Image.FORMAT_L8); pixel.fill(Color(55.0/255.0,0,0))
	var mask := MeshInstance3D.new(); var glow := MeshInstance3D.new()
	for mesh in [mask,glow]:
		mesh.mesh = QuadMesh.new()
		var material := ShaderMaterial.new()
		material.shader = load("res://scripts/lol2/indexed_surface_review.gdshader")
		material.set_shader_parameter("indices",ImageTexture.create_from_image(pixel))
		mesh.material_override = material; world.add_child(mesh)
	mask.layers = 4; mask.material_override.set_shader_parameter("mask_capture",true)
	glow.layers = 128
	glow.material_override.set_shader_parameter("compare_crystal_depth",true)
	glow.material_override.set_shader_parameter("crystal_depth",depth.get_texture())
	var cases := 0
	for distance in [16.0,45.0,63.999,64.0,255.999,256.0,2048.0,16000.0,20000.0]:
		for tilt in [Vector3.ZERO,Vector3(0.3,0.2,0)]:
			mask.position = Vector3(0,0,-distance); mask.rotation = tilt
			mask.mesh.size = Vector2.ONE * distance * 2.0
			glow.mesh.size = mask.mesh.size
			for offset in [-0.05,0.0,0.05]:
				glow.transform = mask.transform
				glow.position += mask.basis.z * offset
				for i in 4: await process_frame
				await RenderingServer.frame_post_draw
				var image := source.get_texture().get_image()
				for y in [32,64,96]:
					for x in [32,64,96]:
						var visible := image.get_pixel(x,y).r > 65.0/255.0
						if visible != (offset >= 0.0):
							print("DEPTH_PIXEL ", depth.get_texture().get_image().get_pixel(x,y), " mask=",mask.global_transform, " camera=",depth.get_child(0).global_transform)
							push_error("Depth comparison mismatch distance=%s tilt=%s offset=%s pixel=%s color=%s" % [distance,tilt,offset,Vector2i(x,y),image.get_pixel(x,y)])
							quit(1); return
						cases += 1
	depth.get_child(0).cull_mask = 4
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var legacy := depth.get_texture().get_image().get_pixel(64,64)
	if absf(legacy.r*255.0-64.0)>1.0 or absf(legacy.g*255.0-64.0)>1.0:
		push_error("Legacy mask output changed"); quit(1); return
	print("PASS crystal_depth_compare: ",cases," pixel cases, near/far byte boundaries, tilted coplanar/front/behind surfaces, legacy source0 mask")
	quit(0)
