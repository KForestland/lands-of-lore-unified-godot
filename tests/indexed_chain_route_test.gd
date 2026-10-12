extends SceneTree
var scene: Node
func _initialize() -> void:
	_run.call_deferred()
func capture_frame(label: String) -> void:
	if not "--chain-visual" in OS.get_cmdline_user_args(): return
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("/home/bob/lol2_out/indexed_chain_visual_20260913")
	assert(root.get_texture().get_image().save_png("/home/bob/lol2_out/indexed_chain_visual_20260913/%s.png" % label) == OK)
func _run() -> void:
	scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(240):
		await process_frame
		if scene.walkthrough_ready: break
	assert(scene.walkthrough_ready and scene.indexed_chain != null)
	await physics_frame
	await physics_frame
	assert(scene._position_chain_approach())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in range(30): await physics_frame
	await capture_frame("intact")
	assert(scene.indexed_chain.strike())
	for i in range(45): await physics_frame
	await capture_frame("breaking")
	for i in range(240): await physics_frame
	await capture_frame("open")
	for door in scene.indexed_doors: assert(door.opening_percent == 100)
	var route := [837, 836, 835, 753, 752, 753, 835, 836, 837, 800]
	if "--chain-branch" in OS.get_cmdline_user_args():
		route.append_array([801, 814, 813, 812, 811, 838, 811, 812, 813, 814, 801, 800])
	for region in route:
		var target := Vector3.ZERO
		for face in scene.data.faces:
			if int(face.region) == region:
				for p in face.points: target += Vector3(p[0], p[1], p[2]) * 64.0 / face.points.size()
				break
		target += scene.native_translation
		var reached := false
		scene.smoke = true
		scene.target = target + Vector3.UP * 32
		scene.route_ticks = 0
		scene.route_limit = 10000
		for tick in range(360):
			var delta: Vector3 = target - scene.player.global_position
			if Vector2(delta.x, delta.z).length() < 6.0:
				reached = true
				break
			scene.player.look_at(Vector3(target.x, scene.player.global_position.y, target.z), Vector3.UP)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			await physics_frame
		print("Indexed route region ", region, " reached=", reached)
		if not reached or absf(scene.player.position.y - target.y - 32) > 1:
			for c in range(scene.player.get_slide_collision_count()):
				var hit = scene.player.get_slide_collision(c)
				print("Contact ", hit.get_position(), " normal ", hit.get_normal())
			push_error("Native-controller route failed at region%d position%s target%s" % [region, scene.player.position, target])
			scene.free()
			quit(1)
			return
	assert(scene.resets == 0, "No fall resets on route")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("Indexed chain route: shared controller physics with automated targets, ", route.size(), " outbound/return waypoints, floor height and no falls passed")
	scene.free()
	quit()
