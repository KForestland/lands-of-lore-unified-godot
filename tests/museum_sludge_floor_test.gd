extends SceneTree
## Museum Sludge floors (tools/prepare_museum_sludge_floor.py): the 47 resource-21 floors the review capture left
## unresolved now draw the original animated sludge, so no Museum face keeps the review debug colour. Checks the
## material group, the 10-frame animation, every manifest region, and rendered pixels in the Long arm chute
## (owner r3 report 11:20:57) against the debug colour.
const DEBUG := Color(0.65, 0.2, 0.55)
func _initialize() -> void:
	_run.call_deferred()

func fail(message: String) -> void:
	push_error(message); print("FAIL " + message); quit(1)

func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/museum_sludge_floor/manifest.json"))
	if manifest.uv.size() != 47 or manifest.frames.size() != 10: return fail("Sludge manifest shape differs")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/museum_review/museum.json"))
	var unresolved := {}
	for face in data.faces:
		if face.material == "unresolved": unresolved[str(int(face.region))] = true
	for region in unresolved:
		if not manifest.uv.has(region): return fail("Unresolved floor region %s has no sludge UV" % region)
	var scene = load("res://scenes/lol2/museum_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	if not scene.materials.has("21"): return fail("Sludge material missing")
	if scene.materials.has("unresolved"): return fail("A Museum face still uses the debug material")
	for key in scene.materials:
		var mat: StandardMaterial3D = scene.materials[key]
		if key != "shell" and mat.albedo_texture == null and mat.albedo_color.is_equal_approx(DEBUG): return fail("Debug colour on material %s" % key)
	var sludge: StandardMaterial3D = scene.materials["21"]
	var first: Texture2D = sludge.albedo_texture
	await create_timer(0.4).timeout
	if sludge.albedo_texture == first: return fail("Sludge floor is not animated")
	# Look straight down at the chute's centre-lane floor (region 965) near the owner's report position.
	var centre := Vector3.ZERO
	for face in data.faces:
		if face.kind == "floor" and int(face.region) == 965:
			for q in face.points: centre += Vector3(q[0], q[1], q[2]) / 4.0
	scene.flying = true
	scene.player.position = centre + Vector3(0, 14 - 24, 0)
	scene.player.rotation = Vector3.ZERO
	scene.camera.rotation = Vector3.ZERO
	scene.camera.look_at(centre + Vector3(0.01, 0, 0))
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if OS.get_environment("SLUDGE_SHOT") != "": image.save_png(OS.get_environment("SLUDGE_SHOT"))
	var magenta := 0; var green := 0; var total := 0
	for y in range(image.get_height() / 3, image.get_height() * 2 / 3, 4):
		for x in range(image.get_width() / 3, image.get_width() * 2 / 3, 4):
			var c := image.get_pixel(x, y); total += 1
			if absf(c.r - DEBUG.r) + absf(c.g - DEBUG.g) + absf(c.b - DEBUG.b) < 0.12: magenta += 1
			if c.g > c.r and c.g > c.b: green += 1
	if magenta > 0: return fail("%d debug-colour samples in the chute" % magenta)
	if green * 2 < total: return fail("Chute floor is not the green sludge (%d/%d green)" % [green, total])
	print("Museum sludge floor passed: 47 regions, 10 frames animated, no debug colour, chute floor green %d/%d" % [green, total])
	scene.free()
	quit()
