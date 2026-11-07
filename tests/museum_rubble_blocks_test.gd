extends SceneTree
## Original rubble-room static blocks 64-76 and 95: source geometry loaded and visible from inside the room.
const Blocks := preload("res://scripts/lol2/museum_rubble_blocks.gd")
func _initialize() -> void:
	_run.call_deferred()
func fail(message: String) -> void:
	print("FAIL ", message)
	quit(1)
func _run() -> void:
	if not Blocks.assets_ready(): return fail("rubble block assets missing")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Blocks.ROOT + "blocks.json"))
	var indices: Dictionary = {}
	for face in data.faces:
		indices[int(face.source_index)] = int(indices.get(int(face.source_index), 0)) + 1
		for point in face.points:
			if point[0] < 390 or point[0] > 529 or point[2] < -1410 or point[2] > -1270: return fail("block face outside rubble room: %s" % [point])
	if indices.keys().size() != 14 or indices.has(179) or indices.has(96): return fail("unexpected placements %s" % [indices])
	for count in indices.values():
		if count != 6: return fail("block is not a closed six-face box %s" % [indices])
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.flying = false
	scene.interface_hud.set_cursor(false)
	var blocks: Node3D = scene.get_node_or_null("MuseumRubbleBlocks")
	if blocks == null: return fail("museum walkthrough did not add rubble blocks")
	scene.control96.set_process(false)
	scene.control96.set_physics_process(false)
	scene.player.position = Vector3(500, 31, -1300)
	var look: Vector3 = Vector3(450, 0, -1390) - scene.player.position
	scene.player.rotation.y = atan2(-look.x, -look.z)
	scene.camera.rotation.x = -0.12
	scene.camera.fov = 75
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	var shown: Image = root.get_texture().get_image()
	blocks.visible = false
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var hidden: Image = root.get_texture().get_image()
	var changed := 0
	for y in range(0, shown.get_height(), 4):
		for x in range(0, shown.get_width(), 4):
			if not shown.get_pixel(x, y).is_equal_approx(hidden.get_pixel(x, y)): changed += 1
	print("RUBBLE_BLOCKS changed_samples=%d placements=%s" % [changed, indices.keys()])
	if changed < 200: return fail("rubble blocks not visible from inside the room")
	DirAccess.make_dir_recursive_absolute("user://tests")
	shown.save_png("user://tests/rubble_blocks_inside.png")
	scene.free()
	print("PASS museum rubble blocks: fourteen original static boxes rendered in regions 329-335")
	quit()
