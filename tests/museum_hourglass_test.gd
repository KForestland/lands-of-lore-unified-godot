extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	var prop = scene.get_node("MuseumHourglass226")
	assert(prop.position == Vector3(1332,10,-663))
	assert(prop.mesh.size == Vector2(100,62))
	var texture: Image = prop.material_override.albedo_texture.get_image()
	assert(texture.get_pixel(0,0).a == 0)
	scene.player.position = Vector3(1332,32,-520)
	scene.player.rotation = Vector3.ZERO
	scene.camera.rotation = Vector3.ZERO
	for i in range(8): await process_frame
	if "--capture-hourglass" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/bob/lol2_out/museum_progression_20260914/hourglass_restored.png")
	print("Hourglass passed: source position/bounds, transparent background, museum scene loads")
	quit()
