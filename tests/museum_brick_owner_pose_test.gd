extends "res://tests/museum_ivory_live_test.gd"
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate();scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame;freeze(scene);scene.flying=false;scene.interface_hud.set_cursor(false);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.player.position=Vector3(472.164337158203,31.0474910736084,-1350.24658203125)
	scene.player.rotation.y=0.36838972568512;scene.camera.rotation.x=-0.0640039145946503;scene.camera.fov=75
	var owner=scene.control96
	owner.set_physics_process(true)
	DirAccess.make_dir_recursive_absolute("user://tests")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("user://tests/brick_owner_before.png")
	var initial:bool=owner.eligible()
	for i in 300:await physics_frame
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("user://tests/brick_owner_after.png")
	var data:Dictionary={"initial_eligible":initial,"control96":owner.checkpoint(),"actor30_present":scene.skeleton_population.state.actors["30"].present}
	var file:=FileAccess.open("user://tests/brick_owner_observation.json",FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
	print("OWNER_POSE ",JSON.stringify(data))
	if not check(owner.state.stage==2 and scene.skeleton_population.state.actors["30"].present,"Owner view did not complete control96 skeleton sequence"):return
	print("PASS owner-view control96 existing sequence completes with restored native walls")
	await finish(scene);quit()
