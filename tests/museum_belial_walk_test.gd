extends "res://tests/museum_ivory_live_test.gd"
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame;freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.player.position=Vector3(343.634826660156,27.0013313293457,-3282.75830078125)
	scene.player.rotation.y=-0.0684262737631798
	var owner=scene.belial;owner.set_physics_process(true);scene.set_physics_process(true)
	var trace:Array=[]
	var key:=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=true;Input.parse_input_event(key)
	var admitted:=false
	for i in 180:
		await physics_frame
		scene.camera.look_at(Vector3(347,29.5,-3423))
		if i%10==0:trace.append({"frame":i,"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"floor":scene.player.is_on_floor(),"target":owner.target()})
		if owner.target():admitted=true;break
	key=InputEventKey.new();key.physical_keycode=KEY_W;key.keycode=KEY_W;key.pressed=false;Input.parse_input_event(key)
	DirAccess.make_dir_recursive_absolute("user://tests")
	var f:=FileAccess.open("user://tests/belial_walk_trace.json",FileAccess.WRITE);f.store_string(JSON.stringify(trace));f.close()
	if not check(admitted,"Belial unreachable from owner pose by ordinary W approach; trace retained"):return
	await press_e()
	if not check(owner.state.phase=="active","Walked E failed"):return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("user://tests/belial_walk.png")
	print("PASS actual W/collision approach from owner report position and actual E; no intermediate teleport or supplied puzzle state")
	await finish(scene);quit()
