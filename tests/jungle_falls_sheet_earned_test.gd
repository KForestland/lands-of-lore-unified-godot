extends SceneTree
## Owner r17 16-53-49 at Jungle (-4540, -1659): a flat grey triangle, "no point and click".
## The r17 water sheet set every UV to (0, 0), so material 808 drew one texel.
## Stand there. The native floor keeps its UVs, and the waterfall picture stays.
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL falls: ", message)
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
	if _skirt(scene):
		fail("A water skirt is still drawn")
		return
	scene.set_physics_process(false)
	scene.player.global_position = Vector3(-4540.018, 26.761, -1659.711)
	scene.player.velocity = Vector3.ZERO
	scene.player.rotation.y = 1.352772
	scene.camera.rotation = Vector3(-0.11100348, 0.0, 0.0)
	for _frame in 8:
		await process_frame
	var image: Image = root.get_texture().get_image()
	var flat := 0
	var tiled := 0
	var samples := 0
	var x0: int = int(image.get_width() * 0.15)
	var x1: int = int(image.get_width() * 0.55)
	var y0: int = int(image.get_height() * 0.62)
	var y1: int = int(image.get_height() * 0.92)
	for y in range(y0, y1, 4):
		for x in range(x0, x1, 4):
			samples += 1
			var color: Color = image.get_pixel(x, y)
			if _near(color, 134, 134, 154):
				flat += 1
			elif _near(color, 97, 97, 121) or _near(color, 117, 117, 138) or _near(color, 85, 85, 105):
				tiled += 1
	if samples < 10:
		fail("The view was empty")
		return
	if flat * 4 > samples:
		fail("The water is one texel")
		return
	if tiled * 8 < samples:
		fail("The water texture did not tile")
		return
	var falls := false
	var fx0: int = int(image.get_width() * 0.30)
	var fx1: int = int(image.get_width() * 0.60)
	var fy0: int = int(image.get_height() * 0.22)
	var fy1: int = int(image.get_height() * 0.48)
	for y in range(fy0, fy1, 4):
		for x in range(fx0, fx1, 4):
			var color: Color = image.get_pixel(x, y)
			if color.g > 0.18 and color.g > color.r and color.g > color.b:
				falls = true
				break
		if falls:
			break
	if not falls:
		fail("The waterfall picture is gone")
		return
	print("PASS falls: stood at (-4540,-1659), the water is tiled, and the waterfall picture is there")
	quit(0)

func _near(color: Color, r: int, g: int, b: int) -> bool:
	return absf(color.r * 255.0 - float(r)) < 3.0 and absf(color.g * 255.0 - float(g)) < 3.0 and absf(color.b * 255.0 - float(b)) < 3.0

func _skirt(node: Node) -> bool:
	if str(node.name).begins_with("WaterSkirt"):
		return true
	for child in node.get_children():
		if _skirt(child as Node):
			return true
	return false
