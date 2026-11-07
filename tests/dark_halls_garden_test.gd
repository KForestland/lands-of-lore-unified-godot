extends SceneTree
## Vel's fruit garden adapter (report 10-16-31): the bed's 24 soil floors draw as grass and the 12 plants show their grown frame.
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/dark_halls/area.json"))
	var soil := 0
	for face in pack.faces:
		if face.kind == "floor" and face.get("material", "") == "96__front": soil += 1
	check(soil == 24, "the pack binds material 96 to exactly the 24 bed floors (%d)" % soil)
	check(pack.animations.has("prop_114") and pack.animations.prop_114.frames.size() == 25, "prop_114 is the 25-frame growth sprite")
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/dark_halls.tscn").instantiate()
	root.add_child(scene)
	for i in 5: await process_frame
	check(scene.garden_bed_faces == 24, "scene: 24 bed floors drawn with the grass material (%d)" % scene.garden_bed_faces)
	check(scene.grown_props == 1, "scene: the plant material uses the grown frame (%d)" % scene.grown_props)
	var grown := Image.load_from_file("res://assets/lol2/generated/dark_halls/" + pack.animations.prop_114.frames[24])
	var first := Image.load_from_file("res://assets/lol2/generated/dark_halls/" + pack.materials.prop_114)
	check(first.get_used_rect().size == Vector2i.ZERO and grown.get_used_rect().size.y > 100, "the first frame is empty, the grown frame is a plant")
	var node: MeshInstance3D = scene.prop_nodes.get(220)
	check(node != null and (node.mesh.material as StandardMaterial3D).albedo_texture.get_image().get_used_rect() == grown.get_used_rect(), "scene: plant record 220 carries the grown frame")
	var bed_floor: Dictionary = {}
	for face in pack.faces:
		if face.kind == "floor" and int(face.region) == 1493: bed_floor = face; break
	check(scene.static_face_material(0, bed_floor) == "97__front", "hook: a bed floor maps to grass")
	check(scene.static_face_material(0, {"kind": "floor", "material": "96__front", "region": 5}) == "96__front", "hook: material 96 outside the bed stays (none exist, rule is explicit)")
	scene.queue_free(); await process_frame
	print("Dark Halls garden: %d failures" % failures)
	if failures == 0: print("PASS dark halls garden: 24 bed floors as grass, 12 plants grown")
	quit(0 if failures == 0 else 1)
