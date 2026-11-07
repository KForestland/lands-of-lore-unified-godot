extends "res://tests/museum_ivory_live_test.gd"
func move_to(point: Vector3) -> void:
	scene.player.position=point
	for i in 3: await physics_frame
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame;freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var owner=scene.worm
	owner.set_physics_process(true)
	if not check(not owner.active and not owner.mesh.visible,"Inactive source selector must be nonvisual"):return
	await move_to(Vector3(-1400,32,-2048))
	if not check(not owner.active,"Stop region cannot start movie"):return
	# Walk west across the narrow region boundary using actual movement input and collision.
	scene.player.rotation.y=PI/2
	scene.set_physics_process(true)
	var key:=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=true;Input.parse_input_event(key)
	for i in 240:
		await physics_frame
		if scene.player.position.x < -1510: break
	key=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=false;Input.parse_input_event(key)
	scene.set_physics_process(false)
	if not check(scene.player.position.x < -1510,"Actual collision walk into east start region"):return
	if not check(owner.active and owner.mesh.visible,"East source start region"):return
	await move_to(Vector3(-1749.3599,32.04146,-1855.66345))
	scene.player.rotation.y=3.09894;scene.camera.rotation.x=-0.0370062999427319;scene.camera.fov=75
	var before: int=owner.current_frame
	for i in 12: await physics_frame
	if not check(owner.active and owner.current_frame!=before,"Movie must advance beyond source region"):return
	DirAccess.make_dir_recursive_absolute("user://tests")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/worm_owner_pose.png")
	var path:="user://tests/worm.json"
	if not check(scene.quicksave(path).is_empty(),"Save active movie"):return
	var saved: Dictionary=owner.checkpoint()
	scene.open_inventory();await process_frame
	var paused: float=owner.elapsed
	for i in 10:await physics_frame
	if not check(owner.elapsed==paused,"Inventory must pause movie"):return
	scene.inventory.close();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await move_to(Vector3(-2010,32,-2050))
	if not check(not owner.active and not owner.mesh.visible and owner.elapsed==0,"West source unload region"):return
	if not check(scene.quickload(path).is_empty() and owner.active and abs(owner.elapsed-saved.elapsed)<0.001,"Restore active movie frame from disk"):return
	freeze(scene);owner.set_physics_process(true);Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await move_to(Vector3(-1400,32,-2048))
	if not check(not owner.active,"East source unload region"):return
	await move_to(Vector3(-1900,32,-2050))
	if not check(owner.active,"West source start region"):return
	owner.set_physics_process(false);owner.elapsed=3.99;owner._physics_process(0.1)
	if not check(owner.active and owner.elapsed<0.11,"Source repeat255 loops after60frames"):return
	var bad: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	bad.checkpoint.museum_worm.elapsed=4
	if not check(not scene.Save.validate(bad).is_empty(),"Out-of-range movie time admitted"):return
	bad.checkpoint.erase("museum_worm")
	if not check(scene.Save.validate(bad).is_empty(),"Legacy checkpoint rejected"):return
	print("PASS source worm start/stop regions, advancing movie, pause, save/load, infinite loop, legacy and invalid checkpoints")
	await finish(scene);quit()
