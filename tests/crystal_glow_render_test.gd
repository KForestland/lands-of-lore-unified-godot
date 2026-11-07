extends SceneTree
var cave: Node3D
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message)
	print("FAIL crystal_glow_render: ", message)
	quit(1)
func settle() -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene = cave
	for i in 900:
		await process_frame
		if cave.walkthrough_ready: break
	if not cave.walkthrough_ready: return fail("Cave not ready")
	cave.set_physics_process(false)
	cave.curse.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var plant: MeshInstance3D = cave.stalagmites.plants[641]
	cave.player.global_position = plant.global_position + Vector3(0,34,-85)
	cave.camera.look_at(plant.to_global(plant.mesh.center_offset))
	await settle()
	var index: int = cave.placed_instances.find(cave.stalagmites.glow.meshes[641])
	if index < 0: return fail("Glow not registered")
	var view: SubViewport = cave.layer_views[index]
	if view.render_target_update_mode != SubViewport.UPDATE_ALWAYS: return fail("Visible glow asleep")
	var before := view.get_texture().get_image().get_data()
	DirAccess.make_dir_recursive_absolute("user://crystal_render")
	root.get_texture().get_image().save_png("user://crystal_render/before.png")
	view.get_texture().get_image().save_png("user://crystal_render/source_before.png")
	var transform: Transform3D = cave.camera.global_transform
	cave.camera.rotate_y(PI)
	await settle()
	if view.render_target_update_mode != SubViewport.UPDATE_DISABLED: return fail("Away glow still updating")
	var cleared := view.get_texture().get_image()
	for y in cleared.get_height():
		for x in cleared.get_width():
			var color := cleared.get_pixel(x,y)
			if color.r > 65.0/255.0 or color.g > 65.0/255.0: return fail("Sleeping view retained nonzero source pixels")
	cave.camera.global_transform = transform
	await settle()
	if view.render_target_update_mode != SubViewport.UPDATE_ALWAYS: return fail("Returned glow did not wake")
	if view.get_texture().get_image().get_data() != before: return fail("Wake source image differs at unchanged pose")
	# A real indexed foreground face must hide the glow, through the production mask-copy path.
	var wall := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(200, 200)
	wall.mesh = quad
	wall.layers = 2
	var pixel := Image.create(1,1,false,Image.FORMAT_L8)
	pixel.fill(Color(60.0/255.0,0,0))
	var material: ShaderMaterial = plant.material_override.duplicate()
	material.set_shader_parameter("sprite",false)
	material.set_shader_parameter("indices",ImageTexture.create_from_image(pixel))
	wall.material_override = material
	cave.add_child(wall)
	wall.global_transform = cave.camera.global_transform
	wall.global_position = cave.camera.global_position - cave.camera.global_basis.z * 25.0
	cave._copy_occluders(wall)
	await settle()
	var blocked := view.get_texture().get_image()
	for y in blocked.get_height():
		for x in blocked.get_width():
			var color := blocked.get_pixel(x,y)
			if color.r > 65.0/255.0 or color.g > 65.0/255.0: return fail("Glow visible through foreground wall")
	wall.visible = false
	cave.sync_render_source(wall)
	await settle()
	if view.get_texture().get_image().get_data() != before: return fail("Hiding foreground wall did not restore glow")
	cave.stalagmites.restore(["cave:prop641:harvest1:Stalagmite"])
	await settle()
	var spent := view.get_texture().get_image().get_data()
	if spent == before: return fail("Pickup did not change glow image")
	root.get_texture().get_image().save_png("user://crystal_render/after.png")
	view.get_texture().get_image().save_png("user://crystal_render/source_after.png")
	cave.stalagmites.restore([])
	await settle()
	if view.get_texture().get_image().get_data() != before: return fail("Rollback source image differs")
	root.get_texture().get_image().save_png("user://crystal_render/rollback.png")
	print("PASS crystal_glow_render: visible/wake updates; offscreen clear then sleep; exact source image on wake and rollback; foreground wall occludes then restores glow; pickup changes glow image")
	print("CAPTURES ", ProjectSettings.globalize_path("user://crystal_render"))
	quit(0)
