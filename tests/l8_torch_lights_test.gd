extends SceneTree
## Owner r18 F10 15-37-14 at (-1712,1218) "way too dark here" + lighting rule (2026-10-30: light sources, not a player cone).
## The Darker Jungle's 13 flaming skull torches (prop template 19) light their surroundings through the night shader
## (l8_night.gd apply_lights). Stand at the owner's pose: the frame is clearly brighter with the torch lights than without,
## two torches stand within 220 units (the clubhouse entrance), and every night material carries the 13 lights.
const POSE := Vector3(-1712.97, 32.04, 1218.34)
const YAW := -3.0768
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL l8 torch lights: ", label)
	return ok

func luminance() -> float:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var w := image.get_width()
	var h := image.get_height()
	var total := 0.0
	var count := 0
	for y in range(int(h * 0.1), int(h * 0.85), 6):
		for x in range(0, w, 6):
			total += image.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxf(float(count), 1.0) * 255.0

func run() -> void:
	var scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not check(scene.ready_for_review, "darker jungle ready"): quit(1); return
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	var torches: PackedVector3Array = scene.torch_lights
	check(torches.size() == 13, "13 skull torches found (%d)" % torches.size())
	var near := 0
	for t in torches:
		if Vector2(t.x - POSE.x, t.z - POSE.z).length() < 220.0: near += 1
	check(near == 2, "two torches within 220 of the owner's spot (%d)" % near)
	var carried := 0
	for material in scene.night_materials:
		if int(material.get_shader_parameter("light_count")) == torches.size(): carried += 1
	check(carried == scene.night_materials.size() and carried > 0, "every night material carries the lights (%d of %d)" % [carried, scene.night_materials.size()])
	scene.player.position = POSE
	scene.player.rotation.y = YAW
	scene.camera.rotation.x = -0.07
	for i in 12: await process_frame
	var lit: float = await luminance()
	scene.set_torch_lights(false)
	for i in 12: await process_frame
	var dark: float = await luminance()
	scene.set_torch_lights(true)
	check(lit > dark * 2.0 and lit >= 8.0, "the owner's spot is clearly brighter with the torches (lit %.1f, without %.1f)" % [lit, dark])
	if failures == 0:
		print("PASS l8 torch lights: 13 skull torches light the Darker Jungle; the owner's dark spot reads %.1f with them and %.1f without" % [lit, dark])
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
