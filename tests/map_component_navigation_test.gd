extends SceneTree
## Component preview navigation on a synthetic review inventory.
## World x = fixed/65536 and z = -fixedY/65536. Child roles are not
## candidates. A bad index does not move the camera. Switching areas
## drops the previous topology groups.

const Review = preload("res://scripts/lol2/all_maps_review.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func fail(reason: String) -> void:
	failures += 1
	print("FAIL ", reason)

func run() -> void:
	var root_dir := "/tmp/map_component_nav_fixture"
	_write_fixture(root_dir)
	var scene = Review.new()
	scene.map_root = root_dir
	root.add_child(scene)
	await process_frame
	if scene.current_area.is_empty():
		fail("fixture area did not load")
		quit(1)
		return
	if scene.component_option.disabled or scene.component_option.item_count != 2:
		fail("area A chooser count %d disabled %s" % [scene.component_option.item_count, scene.component_option.disabled])
	else:
		print("PASS area A lists ", scene.component_option.get_item_text(0), " / ", scene.component_option.get_item_text(1))
	if scene.component_option.get_item_text(0) != "Group1 (1 regions)":
		fail("group label was %s" % scene.component_option.get_item_text(0))
	var before: Vector3 = scene.camera_root.position
	scene._jump_to_component(-1)
	scene._jump_to_component(9)
	if scene.camera_root.position != before:
		fail("invalid component index moved the camera to %s" % scene.camera_root.position)
	else:
		print("PASS invalid component index left the camera")
	scene._jump_to_component(0)
	var arrival := Vector3(5, 10, -7)
	if scene.camera_root.position.distance_to(arrival) > 0.001:
		fail("group with an arrival went to %s" % scene.camera_root.position)
	else:
		print("PASS group arrival preview ", scene.camera_root.position)
	scene._jump_to_component(1)
	# Source Y is positive, so world Z is negative. Eye is mid floor/ceiling.
	# Larger children, floorless helpers and insufficient-clearance primaries are excluded.
	var expected := Vector3(0.5, 20.0, -0.5)
	if scene.camera_root.position.distance_to(expected) > 0.001:
		fail("region preview %s != %s" % [scene.camera_root.position, expected])
	elif scene.camera_root.position.z >= 0.0:
		fail("world Z did not negate source Y")
	else:
		print("PASS primary centroid ", scene.camera_root.position)
	scene._select_area(1)
	await process_frame
	if not scene.component_groups.is_empty() or not scene.component_option.disabled or scene.component_option.item_count != 0:
		fail("area without inventory kept %d groups" % scene.component_groups.size())
	else:
		print("PASS area switch cleared groups")
	var parked: Vector3 = scene.camera_root.position
	scene._jump_to_component(0)
	if scene.camera_root.position != parked:
		fail("disabled chooser still moved the camera")
	scene._select_area(2)
	await process_frame
	if not scene.component_groups.is_empty() or not scene.component_option.disabled:
		fail("sha mismatch still exposed groups")
	else:
		print("PASS sha mismatch disables the chooser")
	scene._select_area(0)
	var geometry_path := root_dir.path_join("A/geometry/geometry.json")
	var mismatched = JSON.parse_string(FileAccess.get_file_as_string(geometry_path))
	mismatched["source"]["sha256"] = "foreign geometry"
	var changed := FileAccess.open(geometry_path, FileAccess.WRITE)
	changed.store_string(JSON.stringify(mismatched))
	changed.close()
	if scene._component_region_preview(scene.component_groups[1]) != null:
		fail("foreign geometry supplied a preview position")
	else:
		print("PASS foreign geometry rejected")
	print("Component navigation: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _write_fixture(root_dir: String) -> void:
	_area(root_dir, "A", "fixture-sha", true)
	_area(root_dir, "B", "fixture-sha-b", false)
	_area(root_dir, "C", "fixture-sha-c", false)
	var mismatch := {
		"schema": "lol2-map-review-inventory-v1",
		"source": {"sha256": "not-the-area-sha"},
		"topology": {"components": [{"component_index": 0, "region_ids": [1], "region_count": 1, "arrival_ids": []}]}
	}
	var file := FileAccess.open(root_dir.path_join("C/review_inventory.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(mismatch))
	file.close()
	var index := {"areas": [
		{"id": "A", "name": "A", "review_file": "A/review.json"},
		{"id": "B", "name": "B", "review_file": "B/review.json"},
		{"id": "C", "name": "C", "review_file": "C/review.json"}]}
	file = FileAccess.open(root_dir.path_join("index.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(index))
	file.close()

func _area(root_dir: String, area_id: String, sha: String, with_inventory: bool) -> void:
	var area_dir := root_dir.path_join(area_id)
	DirAccess.make_dir_recursive_absolute(area_dir.path_join("geometry"))
	var image := Image.create(1, 1, false, Image.FORMAT_RGB8)
	image.set_pixel(0, 0, Color.WHITE)
	image.save_png(area_dir.path_join("tex.png"))
	var review := {
		"id": area_id,
		"name": area_id,
		"source": {"sha256": sha, "file": "fixture"},
		"faces": [{"material": "m", "points": [[0, 0, 0], [1, 0, 0], [0, 0, 1]], "uv": [[0, 0], [1, 0], [0, 1]]}],
		"materials": {"m": "tex.png"},
		"start": [0, 10, 0],
		"arrivals": [{"index": 0, "region": 1, "heading": 0, "position": [5, 10, -7]}]
	}
	var file := FileAccess.open(area_dir.path_join("review.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(review))
	file.close()
	var floorless := PackedByteArray()
	floorless.resize(44)
	floorless[32] = 255
	var geometry := {
		"source": {"sha256": sha},
		"vertices_fixed": [
			[0, 0], [65536, 0], [65536, 65536], [0, 65536],
			[0, 0], [655360, 0], [655360, 655360], [0, 655360],
			[0, 0], [655360, 0], [655360, 131072], [0, 131072]
		],
		"regions": [
			{"id": 1, "record_role": "primary_region", "vertex_indices": [0, 1, 2, 3], "neighbors": [], "floor_corners": [0, 0, 0, 0], "ceiling_corners": [10, 10, 10, 10]},
			{"id": 2, "record_role": "primary_region", "vertex_indices": [0, 1, 2, 3], "neighbors": [], "floor_corners": [0, 0, 0, 0], "ceiling_corners": [40, 40, 40, 40]},
			{"id": 99, "record_role": "floor_subdivision", "owner": 2, "vertex_indices": [4, 5, 6, 7], "neighbors": [], "floor_corners": [0, 0, 0, 0], "ceiling_corners": [80, 80, 80, 80]},
			{"id": 3, "record_role": "primary_region", "vertex_indices": [8, 9, 10, 11], "neighbors": [], "floor_corners": [0, 60, 0, 60], "ceiling_corners": [40, 40, 40, 40]},
			{"id": 4, "record_role": "primary_region", "vertex_indices": [4, 5, 6, 7], "neighbors": [], "floor_corners": [0, 0, 0, 0], "ceiling_corners": [80, 80, 80, 80], "raw_hex": floorless.hex_encode()}
		]
	}
	file = FileAccess.open(area_dir.path_join("geometry/geometry.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(geometry))
	file.close()
	if not with_inventory: return
	var inventory := {
		"schema": "lol2-map-review-inventory-v1",
		"source": {"sha256": sha},
		"topology": {"components": [
			{"component_index": 0, "region_ids": [1], "region_count": 1, "arrival_ids": [0]},
			{"component_index": 1, "region_ids": [99, 3, 4, 2], "region_count": 4, "arrival_ids": []}
		]}
	}
	file = FileAccess.open(area_dir.path_join("review_inventory.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(inventory))
	file.close()
