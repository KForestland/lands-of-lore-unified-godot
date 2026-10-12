extends "res://tests/museum_exhibit_route_test.gd"
## Collision-walked detour from a supplied point on the earned main corridor; no door/quest/item injection.
func press(key: Key) -> void:
	for down in [true,false]:
		var event:=InputEventKey.new();event.keycode=key;event.pressed=down;Input.parse_input_event(event);await process_frame
func run() -> void:
	Engine.time_scale=4;Engine.physics_ticks_per_second=240;Engine.max_physics_steps_per_frame=32
	var scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate();scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;scene.flying=false
	var routes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/museum_ivory_walk_routes.json"))
	var p: Array=routes.start;scene.player.position=Vector3(p[0],p[1],p[2]);scene.set_physics_process(false)
	for i in 60:
		await physics_frame;scene.player.velocity=Vector3(0,-80,0);scene.player.move_and_slide()
	for pair in [["to195",1],["to189",0]]:
		if not await walk_points(scene,routes[pair[0]].points,pair[0]):return
		var n: int=pair[1]
		if not scene.player.is_on_floor():push_error("Ivory detour not grounded");quit(1);return
		scene.camera.look_at(scene.ivory.urns[n].global_position);await press(KEY_Q)
		if scene.ivory.state.stages[n]!=1:push_error("Walked Spark missed urn %d"%n);quit(1);return
		scene.camera.look_at(scene.ivory.chips[n].global_position);await press(KEY_E)
		if scene.ivory.state.stages[n]!=2:push_error("Walked chip pickup failed %d position %s"%[n,scene.player.position]);quit(1);return
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://tests")
		root.get_texture().get_image().save_png("user://tests/ivory_walk_%d.png"%n)
	if not scene.quicksave("user://tests/ivory_walk.json").is_empty():push_error("Ivory walked save failed");quit(1);return
	print("PASS museum_ivory_walk: grounded collision detour from supplied main-corridor position, default puzzle/door/quest state and starting Spark; both actual Q/E pickups; no intermediate teleport, item or unlock injection. Arrival-to-corridor is covered separately, not chained here.")
	quit()
