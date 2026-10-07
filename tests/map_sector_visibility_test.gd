extends SceneTree
const Controller = preload("res://scripts/lol2/map_sector_visibility.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func run() -> void:
	var controller = Controller.new()
	controller.regions.assign([
		{"id":0,"sector":0,"polygon":[[0,0],[100,0],[100,100],[0,100]],"floor":[0,10,10,0],"ceiling":[64,74,74,64]},
		{"id":1,"sector":1,"polygon":[[100,0],[200,0],[200,100],[100,100]],"floor":[0,0,0,0],"ceiling":[64,64,64,64]},
		{"id":2,"sector":2,"polygon":[[0,0],[100,0],[100,100],[0,100]],"floor":[100,100,100,100],"ceiling":[160,160,160,160]}])
	controller.potential_sectors = [[0,1],[1],[2]]
	var image := Image.create(3,1,false,Image.FORMAT_R8)
	image.fill(Color.WHITE)
	controller.mask = ImageTexture.create_from_image(image)
	controller.initialize()
	check(controller.sector_at(Vector3(50,32,50))==0,"source polygon selects sloped lower room")
	check(controller.sector_at(Vector3(50,120,50))==2,"height selects stacked room")
	check(controller.sector_at(Vector3(50,3,50))==-1,"below sloped floor stays unclassified")
	check(controller.sector_at(Vector3(150,32,50))==1,"crossing boundary changes sector")
	check(controller.sector_at(Vector3(500,32,50))==-1,"outside known space stays unclassified")
	controller.set_sector(0)
	image = controller.mask.get_image()
	check(image.get_pixel(0,0).r==1 and image.get_pixel(1,0).r==1 and image.get_pixel(2,0).r==0,"native potential membership becomes GPU mask")
	controller.set_sector(-1)
	image = controller.mask.get_image()
	check(image.get_pixel(0,0).r==1 and image.get_pixel(1,0).r==1 and image.get_pixel(2,0).r==1,"unclassified camera restores all sectors")
	# Native list is directed; do not add an invented reverse link.
	controller.set_sector(1)
	image = controller.mask.get_image()
	check(image.get_pixel(0,0).r==0 and image.get_pixel(1,0).r==1,"directed source membership is preserved")
	controller.free()
	for indexed in [false,true]:
		var view := SubViewport.new()
		view.size = Vector2i(32,32)
		view.own_world_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var cam := Camera3D.new()
		cam.position.z = 2
		cam.cull_mask = 1
		cam.environment = Environment.new()
		cam.environment.background_mode = Environment.BG_COLOR
		cam.environment.background_color = Color.BLACK
		view.add_child(cam)
		var material := ShaderMaterial.new()
		material.shader = preload("res://scripts/lol2/all_maps_indexed_surface.gdshader") if indexed else preload("res://scripts/lol2/all_maps_lit_surface.gdshader")
		var index_image := Image.create(1,1,false,Image.FORMAT_R8)
		index_image.fill(Color(0.5,0,0))
		var palette := Image.create(256,1,false,Image.FORMAT_RGB8)
		palette.fill(Color.WHITE)
		material.set_shader_parameter("indices",ImageTexture.create_from_image(index_image))
		material.set_shader_parameter("palette",ImageTexture.create_from_image(palette))
		material.set_shader_parameter("sector_visibility",true)
		material.set_shader_parameter("use_vertex_light",true)
		var mask_image := Image.create(2,1,false,Image.FORMAT_R8)
		mask_image.fill(Color.WHITE)
		var mask := ImageTexture.create_from_image(mask_image)
		material.set_shader_parameter("sector_mask",mask)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_custom_format(1,SurfaceTool.CUSTOM_RGBA_FLOAT)
		surface.set_custom(1,Color(1,0,0,0))
		for point in [Vector3(-2,-2,0),Vector3(0,2,0),Vector3(2,-2,0)]:
			surface.set_uv(Vector2.ZERO)
			surface.add_vertex(point)
		var mesh := surface.commit()
		mesh.surface_set_material(0,material)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		view.add_child(node)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var shown := view.get_texture().get_image().get_pixel(16,16)
		mask_image.set_pixel(1,0,Color.BLACK)
		mask.update(mask_image)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var hidden := view.get_texture().get_image().get_pixel(16,16)
		check(shown.r>0.2 and hidden.r<0.01,"GPU custom sector channel hides excluded surface, indexed="+str(indexed))
		material.set_shader_parameter("use_vertex_light",false)
		material.set_shader_parameter("render_sector",-1.0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		check(view.get_texture().get_image().get_pixel(16,16).r>0.2,"unbound prop remains visible, indexed="+str(indexed))
		view.queue_free()
		await process_frame
	print("Sector visibility: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
