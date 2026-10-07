extends SceneTree
## Per-frame prop flips and insets, including the exported animation player.

const Review = preload("res://scripts/lol2/all_maps_review.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func fail(reason: String) -> void:
	failures += 1
	print("FAIL ", reason)

func run() -> void:
	var root_dir := "/tmp/map_material_animation_fixture"
	_write_fixture(root_dir)
	var scene = Review.new()
	scene.map_root = root_dir
	root.add_child(scene)
	await process_frame
	if scene.current_area.is_empty():
		fail("fixture area did not load")
		quit(1)
		return
	var varied: Array[MeshInstance3D] = []
	var steady: MeshInstance3D
	for child in scene.props_root.get_children():
		var source: Dictionary = child.get_meta("source")
		if str(source.get("material")) == "steady":
			steady = child
		elif bool(source.get("animated_case")):
			varied.append(child)
	if varied.size() != 2 or steady == null:
		fail("expected two inset props and one steady prop, saw %d" % varied.size())
		quit(1)
		return
	var shared: Material = varied[0].mesh.material
	if shared != varied[1].mesh.material:
		fail("placements that share a flag sequence did not share one material")
	if shared == steady.mesh.material:
		fail("steady prop shared the animated material")
	scene._advance_animations(0.1)
	if not _near(varied[0].mesh.material.uv1_scale, Vector3(-1, 1, 1)):
		fail("frame 1 did not flip U, scale %s" % str(varied[0].mesh.material.uv1_scale))
	else:
		print("PASS frame 1 horizontal flip")
	if not _near(steady.mesh.material.uv1_scale, Vector3(1, 1, 1)):
		fail("steady prop UV changed with the animated material")
	else:
		print("PASS steady material kept its own UV")
	var tall: MeshInstance3D = varied[0] if float(varied[0].get_meta("source").top) > float(varied[1].get_meta("source").top) else varied[1]
	var short: MeshInstance3D = varied[1] if tall == varied[0] else varied[0]
	if not _size_near(tall.mesh, Vector2(34, 84), Vector3(1, 48, 0)):
		fail("tall inset got %s offset %s" % [str(tall.mesh.size), str(tall.mesh.center_offset)])
	elif not _size_near(short.mesh, Vector2(34, 64), Vector3(1, 38, 0)):
		fail("short placement did not keep its own height, %s %s" % [str(short.mesh.size), str(short.mesh.center_offset)])
	else:
		print("PASS per-placement inset and anchor")
	var scene_path := root_dir.path_join("fixture/map.tscn")
	var entry: Dictionary = scene.areas[0]
	var error: Error = scene._save_area_scene(scene_path, "fixture", entry, false, true)
	if error != OK:
		fail("scene save failed %d" % error)
		quit(1)
		return
	var packed: PackedScene = load(scene_path)
	var exported := packed.instantiate()
	root.add_child(exported)
	var animator = exported.get_node_or_null("MaterialAnimations")
	if animator == null or animator.sequences.is_empty():
		fail("exported MaterialAnimations missing")
		quit(1)
		return
	var sequence: Dictionary = {}
	for candidate in animator.sequences:
		if (candidate.get("frame_flags", []) as Array).size() > 1:
			sequence = candidate
	if sequence.is_empty() or (sequence.get("quads", []) as Array).size() != 2:
		fail("exported sequence did not keep both quad resources")
		quit(1)
		return
	animator.advance(0.1)
	var saved_quad: QuadMesh = sequence.quads[0]
	if saved_quad.size.y != 84.0 and saved_quad.size.y != 64.0:
		fail("saved quad did not take frame-1 bounds, size %s" % str(saved_quad.size))
	elif not _near(sequence.material.uv1_scale, Vector3(-1, 1, 1)):
		fail("saved material did not flip on frame 1")
	else:
		print("PASS save/load continues per-frame bounds and flip")
	var shown: MeshInstance3D = exported.get_node("Props").get_child(0)
	if shown.mesh != sequence.quads[0] and shown.mesh != sequence.quads[1]:
		fail("exported prop mesh is not the animation quad resource")
	else:
		print("PASS exported prop uses the embedded quad")
	print("Map material animation: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _size_near(mesh: QuadMesh, size: Vector2, center: Vector3) -> bool:
	return mesh.size.is_equal_approx(size) and mesh.center_offset.is_equal_approx(center)

func _near(got: Vector3, expect: Vector3) -> bool:
	return got.is_equal_approx(expect)

func _frame(flags: int, left_inset: int, top_trim: int, right_inset: int, bottom: int) -> String:
	var raw := PackedByteArray()
	raw.resize(12)
	raw[2] = flags
	raw[5] = left_inset
	raw[6] = top_trim
	raw[7] = right_inset
	raw[8] = bottom
	return raw.hex_encode()

func _write_fixture(root_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(root_dir.path_join("fixture"))
	var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
	image.fill(Color(1, 1, 1))
	for name in ["a0.png", "a1.png", "still.png"]:
		image.save_png(root_dir.path_join("fixture").path_join(name))
	var state := PackedByteArray()
	state.resize(16)
	state[14] = 40
	var first := _frame(0, 0, 0, 0, 0)
	var second := _frame(64, 4, 10, 2, 6)
	var flags := [0, 64, 64, 64, 0, 0, 0, 0]
	var hexes := [first, second, second, second, first, first, first, first]
	var area := {
		"id": "fixture",
		"name": "Animation fixture",
		"start": [0, 0, 0],
		"materials": {"flicker": "a0.png", "steady": "still.png"},
		"animations": {"flicker": {"frames": ["a0.png", "a1.png", "a0.png", "a0.png", "a0.png", "a0.png", "a0.png", "a0.png"], "fps": 10}},
		"faces": [{
			"material": "steady",
			"points": [[0, 0, 0], [1, 0, 0], [1, 1, 0]],
			"uv": [[0, 0], [1, 0], [1, 1]],
		}],
		"props": [
			_prop("flicker", 100.0, state.hex_encode(), hexes, flags, true),
			_prop("flicker", 80.0, state.hex_encode(), hexes, flags, true),
			_prop("steady", 20.0, state.hex_encode(), [first], [0], false),
		],
	}
	var index := {"areas": [{"id": "fixture", "name": "Animation fixture", "review_file": "fixture/area.json"}]}
	FileAccess.open(root_dir.path_join("index.json"), FileAccess.WRITE).store_string(JSON.stringify(index))
	FileAccess.open(root_dir.path_join("fixture/area.json"), FileAccess.WRITE).store_string(JSON.stringify(area))

func _prop(id: String, top: float, state_hex: String, hexes: Array, flags: Array, animated_case: bool) -> Dictionary:
	var raw: PackedByteArray = str(hexes[0]).hex_decode()
	var half := 20.0
	var left := -half + float(raw[5])
	var right := half - float(raw[7])
	var bottom := float(raw[8])
	return {
		"material": id, "billboard": true, "animated_case": animated_case,
		"left": left, "right": right, "bottom": bottom, "top": top,
		"position": [0, 0, 0], "state_hex": state_hex,
		"frame_hex": hexes[0], "frame_hexes": hexes, "frame_flags_list": flags,
	}
