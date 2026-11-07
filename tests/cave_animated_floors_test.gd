extends SceneTree
## Cave lava, tar and water floors cycle their original phase-group frames; the lethal material135
## regions are drawn as lava instead of the unresolved placeholder, and lethality is unchanged.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	current_scene = cave
	for frame in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	assert(cave.walkthrough_ready and cave.lava.regions.size() == 86, "Lava lethality regions unchanged")
	assert(cave.material_cache.has(cave.LAVA_KEY), "Material135 regions are rebound to lava")
	assert(cave.material_cache.has("unresolved"), "The seven other unresolved floors keep their placeholder")
	var animation: Node = cave.floor_animation
	assert(animation != null and animation.sequences.size() == 4, "Lava, two tar and water groups animate")
	var counts: Dictionary = {}
	var lava: Dictionary = {}
	for sequence in animation.sequences:
		counts[sequence.frames.size()] = int(counts.get(sequence.frames.size(), 0)) + 1
		if sequence.frames.size() == 10: lava = sequence
	assert(counts == {10: 1, 5: 3}, "Original group sizes: lava 10, tar/pool/water 5")
	var material: ShaderMaterial = lava.material
	animation.set_process(false)
	lava.elapsed = 0.0
	animation.advance(0.0)
	var first: Texture2D = material.get_shader_parameter("indices")
	assert(first == lava.frames[0])
	animation.advance(1.0 / float(lava.fps) + 0.001)
	assert(material.get_shader_parameter("indices") == lava.frames[1], "Lava steps to its next original frame")
	animation.advance(9.0 / float(lava.fps))
	assert(material.get_shader_parameter("indices") == lava.frames[0], "Lava loops through all ten frames")
	# Rendered check: looking down at lava pool 1471 shows lava colours, not the magenta placeholder.
	var region: Dictionary
	for candidate in cave.lava.regions:
		if candidate.id == 1471: region = candidate
	var center := Vector2.ZERO
	for vertex in region.polygon: center += vertex / region.polygon.size()
	cave.flying = true
	cave.player.global_position = Vector3(center.x, region.floor + 140, center.y + 260) + cave.native_translation
	cave.player.velocity = Vector3.ZERO
	cave.player.rotation.y = 0.0
	cave.camera.rotation.x = -0.45
	for frame in range(10): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	var lava_pixels := 0
	var magenta := 0
	for y in range(int(image.get_height() * 0.55), int(image.get_height() * 0.85), 6):
		for x in range(int(image.get_width() * 0.5), int(image.get_width() * 0.75), 6):
			var c := image.get_pixel(x, y)
			if c.r > 0.3 and c.r > c.g * 1.6 and c.r > c.b * 2.0: lava_pixels += 1
			if c.r > 0.6 and c.b > 0.35 and c.g < 0.3: magenta += 1
	print("lava pixels %d magenta %d" % [lava_pixels, magenta])
	assert(lava_pixels > 100 and magenta == 0, "Lava pool renders original lava")
	print("PASS cave animated floors: lava rebound, 4 groups, frame cycle, rendered lava")
	quit()
