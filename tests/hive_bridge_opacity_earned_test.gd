extends SceneTree
## Owner r17 16-48-43 at Hive (-1140, -6018): the lava bridge looked transparent.
## Stand where the owner stood and read the floor. Material 21 stays opaque.
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL bridge: ", message)
	quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for _i in 40:
		await process_frame
		if scene.get("ready_for_review"):
			break
	if not scene.get("ready_for_review"):
		fail("Hive not ready")
		return
	scene.set_physics_process(false)
	var mat: StandardMaterial3D = scene.materials["21"]
	if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		fail("Material 21 is blended")
		return
	var tex_image: Image = mat.albedo_texture.get_image()
	if tex_image == null or tex_image.detect_alpha() != Image.ALPHA_NONE:
		fail("Material 21 texture has an alpha channel")
		return
	scene.player.global_position = Vector3(-1140.433, -203.0, -6018.336)
	scene.player.velocity = Vector3.ZERO
	scene.player.rotation.y = -1.433983
	scene.camera.rotation = Vector3(-0.216004, 0.0, 0.0)
	for _frame in 6:
		await process_frame
	var image: Image = root.get_texture().get_image()
	var crack := false
	var x0: int = int(image.get_width() * 0.3)
	var x1: int = int(image.get_width() * 0.7)
	var y0: int = int(image.get_height() * 0.55)
	var y1: int = int(image.get_height() * 0.9)
	for y in range(y0, y1, 4):
		for x in range(x0, x1, 4):
			var color: Color = image.get_pixel(x, y)
			if color.a < 0.99:
				fail("The view is clear at %s" % color)
				return
			if color.r > 0.35 and color.r > color.g + 0.15:
				crack = true
	if not crack:
		fail("The bridge floor did not draw the stone")
		return
	print("PASS bridge: stood at (-1140,-6018), material 21 is opaque, and the floor shows the stone")
	quit(0)
