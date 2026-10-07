extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene: Node3D = load("/home/bob/lol2_out/all_maps_20260922/L16_CA/map.scn").instantiate()
	scene.position = Vector3(1000,500,2000)
	root.add_child(scene)
	var controller = scene.get_node("SectorVisibility")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.global_position = scene.to_global(Vector3(204.58905029296875,72,1558.0023803710938))
	await process_frame
	await process_frame
	assert(controller.active_sector==25,"Saved controller must resolve camera in translated scene")
	var mask := controller.mask.get_image() as Image
	assert(mask.get_pixel(25,0).r==1 and mask.get_pixel(172,0).r==0)
	var bound := 0
	for node in scene.get_node("Geometry").get_children():
		if not node is MeshInstance3D: continue
		var material = node.mesh.surface_get_material(0)
		if material is ShaderMaterial:
			assert(material.get_shader_parameter("sector_mask")==controller.mask,"Saved renderer and controller must share mask")
			bound += 1
	assert(bound>0)
	camera.global_position = scene.to_global(Vector3(100000,100000,100000))
	await process_frame
	await process_frame
	assert(controller.active_sector==-1)
	assert(controller.mask.get_image().get_pixel(172,0).r==1)
	print("Saved sector visibility: PASS; translated camera25, excluded172, shared mask ",bound," materials, outside fallback")
	scene.queue_free()
	camera.queue_free()
	await process_frame
	quit(0)
