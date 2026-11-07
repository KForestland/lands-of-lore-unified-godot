extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var view := SubViewport.new(); view.size=Vector2i(256,16); view.msaa_3d=Viewport.MSAA_DISABLED
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
	var camera := Camera3D.new(); view.add_child(camera); camera.position.z=1; camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=2; camera.keep_aspect=Camera3D.KEEP_WIDTH; camera.current=true
	var mesh := MeshInstance3D.new(); mesh.mesh=QuadMesh.new(); mesh.mesh.size=Vector2(2,0.125)
	var material := ShaderMaterial.new(); var shader := Shader.new()
	shader.code="shader_type spatial; render_mode unshaded,fog_disabled; void fragment(){ float n=floor(UV.x*256.0); vec3 v=vec3(128.0); int channel=int(floor(UV.y*3.0)); v[channel]=n; ALBEDO=v/255.0; }"
	material.shader=shader; mesh.material_override=material; view.add_child(mesh)
	var sampled := SubViewport.new(); sampled.size=view.size; sampled.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(sampled)
	var rect := ColorRect.new(); rect.size=Vector2(256,16); sampled.add_child(rect)
	var check := ShaderMaterial.new(); var check_shader := Shader.new()
	check_shader.code="shader_type canvas_item; uniform sampler2D packed: filter_nearest,repeat_disable; void fragment(){ vec3 b=round(texture(packed,UV).rgb*255.0); int channel=int(floor(UV.y*3.0)); float expected=floor(UV.x*256.0); bool ok=expected<128.0 || b[channel]==expected; COLOR=ok?vec4(1.0):vec4(1.0,0.0,0.0,1.0); }"
	check.shader=check_shader; check.set_shader_parameter("packed",view.get_texture()); rect.material=check
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	var raw := view.get_texture().get_image(); var decoded := sampled.get_texture().get_image()
	for channel in 3:
		var y: int = [2,8,13][channel]
		for x in range(128,256):
			var value := roundi(raw.get_pixel(x,y)[channel]*255)
			if value != x or decoded.get_pixel(x,y).g < 0.99:
				push_error("Depth channel %s at byte%s readback%s GPU%s" % [channel,x,value,decoded.get_pixel(x,y)]); quit(1); return
	print("PASS depth_channel_probe: all384 independent RGB channel values128..255 preserved in get_image and GPU texture/round decode; MSAA disabled")
	quit()
