extends SceneTree
## Owner r17 17-00-05 at Jungle (3014,-4119) h-88, looking up: the gorge had no roof, so the sky and the
## trees showed. The native 744 ceilings stay off the sky. The same quads sit on the opening at -10.
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL roof: ", message)
	quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for _i in 1500:
		await process_frame
		if scene.get("ready_for_review"):
			break
	if not scene.get("ready_for_review"):
		fail("Jungle not ready")
		return
	scene.set_physics_process(false)
	await _stand(Vector3(3013.965, -87.962, -4119.252), -0.134389, 0.816056)
	var below: float = _black_fraction()
	if below < 0.45:
		fail("The gorge roof is open (black %.2f)" % below)
		return
	await _stand(Vector3(3013.965, 32.0, -4119.252), -0.134389, 0.816056)
	var above: float = _black_fraction()
	if above > 0.2:
		fail("The bank looks up into the roof (black %.2f)" % above)
		return
	print("PASS roof: stood in the gorge at (3014,-4119) under a black roof, and the bank still sees the sky")
	quit(0)

func _stand(at: Vector3, yaw: float, pitch: float) -> void:
	scene.player.global_position = at
	scene.player.velocity = Vector3.ZERO
	scene.player.rotation.y = yaw
	scene.camera.rotation = Vector3(pitch, 0.0, 0.0)
	for _frame in 6:
		await process_frame

func _black_fraction() -> float:
	var image: Image = root.get_texture().get_image()
	var black := 0
	var samples := 0
	var x0: int = int(image.get_width() * 0.25)
	var x1: int = int(image.get_width() * 0.75)
	var y0: int = int(image.get_height() * 0.08)
	var y1: int = int(image.get_height() * 0.55)
	for y in range(y0, y1, 4):
		for x in range(x0, x1, 4):
			samples += 1
			var color: Color = image.get_pixel(x, y)
			if color.r < 0.04 and color.g < 0.04 and color.b < 0.04:
				black += 1
	if samples == 0:
		return 0.0
	return float(black) / float(samples)
