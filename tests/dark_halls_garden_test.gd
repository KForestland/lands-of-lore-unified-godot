extends SceneTree
## The bed starts as soil and the fruit starts bare. The chain pull grows them.
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
	check(scene.garden_bed_faces == 0, "scene: the bed is not grass before the pull (%d)" % scene.garden_bed_faces)
	check(scene.grown_props == 0, "scene: the plants are not forced grown (%d)" % scene.grown_props)
	var grown := Image.load_from_file("res://assets/lol2/generated/dark_halls/" + pack.animations.prop_114.frames[20])
	var first := Image.load_from_file("res://assets/lol2/generated/dark_halls/" + pack.materials.prop_114)
	check(first.get_used_rect().size == Vector2i.ZERO and grown.get_used_rect().size.y > 100, "frame 0 is empty and frame 20 is a plant")
	var node: MeshInstance3D = scene.prop_nodes.get(220)
	check(node != null and (node.mesh.material as StandardMaterial3D).albedo_texture.get_image().get_used_rect() == first.get_used_rect(), "scene: plant record 220 starts bare")
	var bed_floor: Dictionary = {}
	for face in pack.faces:
		if face.kind == "floor" and int(face.region) == 1493: bed_floor = face; break
	check(scene.static_face_material(0, bed_floor) == "96__front", "hook: a bed floor stays soil until the pull")
	var atrium: Node = scene.get_node("DarkHallsAtrium")
	check(not bool(atrium.call("is_open")), "the roof starts shut")
	check(bool(atrium.call("open_roof")), "the pull runs")
	check(bool(atrium.call("is_open")), "the roof stays open")
	check((node.mesh.material as StandardMaterial3D).albedo_texture.get_image().get_used_rect() == grown.get_used_rect(), "the pull shows fruit frame 20")
	var meshes: Array = atrium.get("bed_meshes")
	var bed := meshes[0] as MeshInstance3D
	check(bed != null and bed.material_override == atrium.get("grass"), "the pull turns the bed to grass")
	scene.queue_free(); await process_frame
	print("Dark Halls garden: %d failures" % failures)
	if failures == 0: print("PASS dark halls garden: the pull opens the roof, turns the bed to grass, and grows frame 20")
	quit(0 if failures == 0 else 1)
