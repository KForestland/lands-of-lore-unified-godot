extends SceneTree
## Indexed all-maps review: missing contract, cave-sprite shader sample,
## source index 0, occluder index 0, and a two-layer shadow remap.

const Review = preload("res://scripts/lol2/all_maps_indexed_review.gd")
const Surface = preload("res://scripts/lol2/all_maps_indexed_surface.gdshader")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func fail(reason: String) -> void:
	failures += 1
	print("FAIL ", reason)

func run() -> void:
	var review = Review.new()
	var missing: Dictionary = review._merge_indexed_contract({}, "/tmp/does-not-exist-indexed", {})
	if str(missing.get("error", "")).is_empty():
		fail("missing indexed data did not report an error")
	else:
		print("PASS missing contract: ", missing.error)
	review.free()
	var root_dir := "/tmp/all_maps_indexed_fixture"
	_write_fixture(root_dir)
	var scene = Review.new()
	scene.map_root = root_dir
	root.add_child(scene)
	scene.camera.set_frustum(8.0, Vector2(0.5, -0.3), 0.5, 1000.0)
	scene._sync_camera(scene.base_camera)
	var projection_probe: Vector3 = scene.camera.global_position - scene.camera.global_basis.z * 20.0
	if scene.base_camera.unproject_position(projection_probe).distance_to(scene.camera.unproject_position(projection_probe)) > 0.001:
		fail("indexed camera lost off-center frustum")
	else:
		print("PASS indexed off-center frustum synchronization")
	scene.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	scene.camera.size = 8.0
	await _mask_equality()
	if not scene.contract_error.is_empty():
		fail("fixture contract: " + scene.contract_error)
		quit(1)
		return
	await _cave_sprite_sample()
	var frames := 0
	while not scene.layers_clean and frames < 40:
		await process_frame
		frames += 1
	for i in 8:
		await process_frame
		frames += 1
	if not scene.layers_clean:
		fail("indexed layers did not settle (%d frames, visible %s)" % [frames, str(scene.visible_ids)])
	else:
		await _expect_pixels(scene)
		await _switch_and_move(scene)
		_huge_quad(scene)
		scene.benchmark_frames = 8
		scene.benchmark_quit = false
		var bench_wait := 0
		while scene.benchmark_report.is_empty() and bench_wait < 80:
			await process_frame
			bench_wait += 1
		if scene.benchmark_report.is_empty():
			fail("benchmark produced no samples")
		else:
			print("PASS bounded benchmark avg_ms %.2f max_ms %.2f avg_passes %.1f" % [
				scene.benchmark_report.avg_ms, scene.benchmark_report.max_ms, scene.benchmark_report.avg_passes])
	if failures == 0:
		var shot := "/tmp/all_maps_indexed_l1.png"
		scene.capture_path = shot
		for i in 12:
			await process_frame
			if FileAccess.file_exists(shot):
				break
		if FileAccess.file_exists(shot):
			print("PASS screenshot ", shot)
		else:
			fail("screenshot was not written")
			quit(1)
			return
	print("Indexed all-maps tests: %s" % ("PASS" if failures == 0 else "FAIL"))
	if failures > 0:
		quit(1)

func _write_fixture(root_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(root_dir.path_join("fixture"))
	var rgb := Image.create(1, 1, false, Image.FORMAT_RGB8)
	rgb.fill(Color(0.2, 0.2, 0.2))
	rgb.save_png(root_dir.path_join("fixture/rgb.png"))
	var wall := Image.create(1, 1, false, Image.FORMAT_R8)
	wall.fill(Color(10.0 / 255.0, 0, 0))
	wall.save_png(root_dir.path_join("fixture/wall.png"))
	var far := Image.create(2, 2, false, Image.FORMAT_R8)
	far.fill(Color(1.0 / 255.0, 0, 0))
	far.save_png(root_dir.path_join("fixture/far.png"))
	var near := Image.create(2, 2, false, Image.FORMAT_R8)
	near.fill(Color(1.0 / 255.0, 0, 0))
	near.set_pixel(0, 0, Color(0, 0, 0))
	near.set_pixel(0, 1, Color(0, 0, 0))
	near.save_png(root_dir.path_join("fixture/near.png"))
	var block := Image.create(1, 1, false, Image.FORMAT_R8)
	block.fill(Color(40.0 / 255.0, 0, 0))
	block.save_png(root_dir.path_join("fixture/block.png"))
	var palette := Image.create(256, 1, false, Image.FORMAT_RGB8)
	palette.fill(Color(0, 0, 0))
	palette.set_pixel(10, 0, Color(1, 0, 0))
	palette.set_pixel(20, 0, Color(0, 1, 0))
	palette.set_pixel(30, 0, Color(0, 0, 1))
	palette.set_pixel(40, 0, Color(1, 1, 1))
	palette.set_pixel(1, 0, Color(1, 1, 0))
	palette.set_pixel(50, 0, Color(1, 0, 1))
	palette.set_pixel(60, 0, Color(0, 1, 1))
	palette.save_png(root_dir.path_join("fixture/palette.png"))
	var zero_mask := Image.create(1, 1, false, Image.FORMAT_R8)
	zero_mask.fill(Color(0, 0, 0))
	zero_mask.save_png(root_dir.path_join("fixture/block_mask.png"))
	var plain := Image.create(1, 1, false, Image.FORMAT_R8)
	plain.fill(Color(1.0 / 255.0, 0, 0))
	plain.save_png(root_dir.path_join("fixture/plain1.png"))
	var pano_rgb := Image.create(8, 2, false, Image.FORMAT_RGB8)
	pano_rgb.fill(Color(0.1, 0.1, 0.1))
	pano_rgb.save_png(root_dir.path_join("fixture/pano.png"))
	var pano_idx := Image.create(8, 2, false, Image.FORMAT_R8)
	pano_idx.fill(Color(50.0 / 255.0, 0, 0))
	for x in [1, 2, 3]:
		for y in 2:
			pano_idx.set_pixel(x, y, Color(60.0 / 255.0, 0, 0))
	pano_idx.save_png(root_dir.path_join("fixture/pano_idx.png"))
	var remap := PackedByteArray()
	remap.resize(256)
	for i in 256:
		remap[i] = i
	remap[10] = 20
	remap[20] = 30
	var area := {
		"id": "fixture",
		"name": "Indexed fixture",
		"start": [0, 2, 8],
		"palette_image": "palette.png",
		"sprite_initial_remap": {"remap_hex": remap.hex_encode()},
		"alpha_cutout_materials": ["far", "near"],
		"shadow_masks": {"plain1": "block_mask.png"},
		"environment": {"panorama": {"image": "pano.png", "indices": "pano_idx.png", "width": 8, "height": 2}},
		"materials": {"wall": "rgb.png", "far": "rgb.png", "near": "rgb.png", "block": "rgb.png", "plain1": "rgb.png"},
		"indexed_materials": {"wall": "wall.png", "far": "far.png", "near": "near.png", "block": "block.png", "plain1": "plain1.png"},
		"faces": [{
			"material": "wall",
			"points": [[-4, 0, 0], [4, 0, 0], [4, 4, 0], [-4, 4, 0]],
			"uv": [[0, 0], [1, 0], [1, 1], [0, 1]],
		}],
		"props": [
			_prop("far", -1.0, 1.0, 1.0, 3.0, 2.0),
			_prop("near", -1.0, 1.0, 1.0, 3.0, 4.0),
			_prop("block", 1.6, 2.8, 1.0, 3.0, 6.0),
			_prop("plain1", -2.8, -2.0, 1.0, 3.0, 5.0),
		],
	}
	var other := {
		"id": "other", "name": "Other", "start": [0, 2, 8],
		"palette_image": "palette.png",
		"materials": {"wall": "rgb.png"},
		"indexed_materials": {"wall": "wall.png"},
		"faces": area.faces,
		"props": [],
	}
	FileAccess.open(root_dir.path_join("fixture/other.json"), FileAccess.WRITE).store_string(JSON.stringify(other))
	var index := {"areas": [
		{"id": "fixture", "name": "Indexed fixture", "review_file": "fixture/area.json"},
		{"id": "other", "name": "Other", "review_file": "fixture/other.json"},
	]}
	FileAccess.open(root_dir.path_join("index.json"), FileAccess.WRITE).store_string(JSON.stringify(index))
	FileAccess.open(root_dir.path_join("fixture/area.json"), FileAccess.WRITE).store_string(JSON.stringify(area))

func _prop(id: String, left: float, right: float, bottom: float, top: float, z: float) -> Dictionary:
	return {
		"material": id, "billboard": true,
		"left": left, "right": right, "bottom": bottom, "top": top,
		"position": [0, 0, z],
	}

func _switch_and_move(scene) -> void:
	var before := int(scene.source_views.size())
	if before < 2:
		fail("expected shadow source views before the area switch, saw %d" % before)
		return
	scene._select_area(1)
	for i in 4:
		await process_frame
	if scene.source_views.size() != 0:
		fail("area without shadow sprites kept %d source views" % scene.source_views.size())
	else:
		print("PASS area switch dropped stale source views")
	scene.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	scene.camera.size = 8.0
	scene.camera_root.position = Vector3(0, 2, 8)
	scene.camera_root.rotation = Vector3.ZERO
	scene._select_area(0)
	scene.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	scene.camera.size = 8.0
	for i in 8:
		await process_frame
	scene.camera_root.position.x = 0.2
	for i in 4:
		await process_frame
	var view_size: Vector2i = scene.base_view.size
	var half_h := float(scene.camera.size) * 0.5
	var half_w := half_h * float(view_size.x) / float(view_size.y)
	var image := root.get_viewport().get_texture().get_image()
	var both := _pixel(image, _screen(0.7, 2.0, half_w, half_h, view_size, 0.2))
	if scene.source_views.size() < 2:
		fail("returning to the shadow area restored %d source views" % scene.source_views.size())
	elif not _near(both, Color(0, 0, 1)):
		fail("shadow composition after switch and move expected blue, got %s" % str(both))
	else:
		print("PASS shadow composition after area switch and movement")

func _huge_quad(scene) -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(8000, 8000)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	scene.add_child(instance)
	instance.global_position = scene.camera.global_position - scene.camera.global_basis.z * 30.0
	var accepted: bool = scene._prop_in_frustum(instance)
	instance.queue_free()
	if accepted:
		print("PASS huge quad crossing the viewport is kept")
	else:
		fail("huge quad crossing the viewport was culled")

func _cave_sprite_sample() -> void:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = Surface
	shader_material.set_shader_parameter("indices", load("res://assets/lol2/generated/special_cave_review/sprite_474.png"))
	shader_material.set_shader_parameter("sprite", true)
	shader_material.set_shader_parameter("source_id", 0)
	shader_material.set_shader_parameter("active_view", 0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	mesh.material = shader_material
	var view := SubViewport.new()
	view.size = Vector2i(32, 32)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	world.add_child(instance)
	var cam := Camera3D.new()
	cam.cull_mask = 1
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.0
	cam.environment = Environment.new()
	cam.environment.background_mode = Environment.BG_COLOR
	cam.environment.background_color = Color(64.0 / 255.0, 64.0 / 255.0, 0.0)
	world.add_child(cam)
	cam.current = true
	cam.position = Vector3(0, 0, 2)
	for i in 4:
		await process_frame
	var image := view.get_texture().get_image()
	var center := _decode(image.get_pixel(16, 16))
	var corner := _decode(image.get_pixel(0, 0))
	view.queue_free()
	if center == 0:
		fail("cave sprite 474 center indexed sample is empty")
	elif corner != 0:
		fail("cave sprite 474 index 0 was not discarded, got %d" % corner)
	else:
		print("PASS cave sprite 474 shader sample center %d, discarded corner" % center)

func _expect_pixels(scene) -> void:
	var view_size: Vector2i = scene.base_view.size
	var half_h := float(scene.camera.size) * 0.5
	var half_w := half_h * float(view_size.x) / float(view_size.y)
	var resolved := root.get_viewport().get_texture().get_image()
	if resolved == null:
		fail("root resolve image is empty")
		return
	var left := _pixel(resolved, _screen(-0.7, 2.0, half_w, half_h, view_size))
	var both := _pixel(resolved, _screen(0.7, 2.0, half_w, half_h, view_size))
	var blocked := _pixel(resolved, _screen(2.2, 2.0, half_w, half_h, view_size))
	if not _near(left, Color(0, 1, 0)):
		fail("single remap (source 0 on the near sprite) expected green, got %s" % str(left))
	else:
		print("PASS source 0 keeps a single remap")
	if not _near(both, Color(0, 0, 1)):
		fail("double remap expected blue, got %s" % str(both))
	else:
		print("PASS index 1 remaps twice")
	if not _near(blocked, Color(1, 1, 1)):
		fail("occluder expected white, got %s" % str(blocked))
	else:
		print("PASS opaque occluder keeps the base index")
	var far_id := 0
	var near_id := 0
	for child in scene.props_root.get_children():
		var material = child.mesh.surface_get_material(0)
		var source_id := int(material.get_shader_parameter("source_id"))
		var prop_z := float(child.position.z)
		if is_equal_approx(prop_z, 2.0):
			far_id = source_id
		elif is_equal_approx(prop_z, 4.0):
			near_id = source_id
	var far_image: Image = scene.source_views[far_id].get_texture().get_image() if scene.source_views.has(far_id) else null
	var near_image: Image = scene.source_views[near_id].get_texture().get_image() if scene.source_views.has(near_id) else null
	if far_image == null or near_image == null:
		fail("missing source views %s" % str(scene.source_views.keys()))
		return
	var far_shadow := _decode(_pixel(far_image, _screen(0.7, 2.0, half_w, half_h, view_size)))
	var far_blocked := _decode(_pixel(far_image, _screen(2.2, 2.0, half_w, half_h, view_size)))
	var near_hole := _decode(_pixel(near_image, _screen(-0.7, 2.0, half_w, half_h, view_size)))
	if far_shadow != 1 or far_blocked != 0 or near_hole != 0:
		fail("source buffer far shadow %d, far occluded %d, near hole %d" % [far_shadow, far_blocked, near_hole])
	else:
		print("PASS source buffers: shadow 1, occluder 0, sprite hole 0")
	var plain := _pixel(resolved, _screen(-2.4, 2.0, half_w, half_h, view_size))
	if not _near(plain, Color(1, 1, 0)):
		fail("all-zero mask index 1 expected ordinary yellow, got %s" % str(plain))
	else:
		print("PASS explicit zero mask keeps index 1 as color")
	var sky_before := _pixel(resolved, _screen(0.0, 5.5, half_w, half_h, view_size))
	var sky_at := _screen(0.0, 5.5, half_w, half_h, view_size)
	var sky_index := _decode(scene.base_view.get_texture().get_image().get_pixel(sky_at.x, sky_at.y))
	if not _near(sky_before, Color(1, 0, 1)):
		fail("indexed sky at yaw 0 expected magenta index 50, got %s packed %d" % [str(sky_before), sky_index])
	else:
		print("PASS indexed panorama sky")
	var root_sky = scene.map_environment.environment.sky.sky_material
	var indexed_flag = root_sky.get_shader_parameter("indexed")
	if indexed_flag == true:
		fail("root panorama was switched to indexed")
	scene.camera_root.position.x += 0.2
	for i in 4:
		await process_frame
	resolved = root.get_viewport().get_texture().get_image()
	view_size = scene.base_view.size
	half_h = float(scene.camera.size) * 0.5
	half_w = half_h * float(view_size.x) / float(view_size.y)
	var moved := _pixel(resolved, _screen(0.7, 2.0, half_w, half_h, view_size, 0.2))
	if not _near(moved, Color(0, 0, 1)):
		fail("moving camera lost the double remap, got %s" % str(moved))
	else:
		print("PASS shadows survive a moving camera")
	scene.camera_root.rotation.y = -PI / 2.0
	for i in 4:
		await process_frame
	resolved = root.get_viewport().get_texture().get_image()
	var sky_yaw := _pixel(resolved, sky_at)
	if not _near(sky_yaw, Color(0, 1, 1)):
		fail("yawed indexed sky expected cyan, got %s" % str(sky_yaw))
	else:
		print("PASS moving camera switches indexed sky column")

func _mask_equality() -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform int expected_mask = 0;
varying flat uint seen_layers;
void vertex() { seen_layers = CAMERA_VISIBLE_LAYERS; }
void fragment() {
	ALBEDO = seen_layers == uint(expected_mask) ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
}
"""
	var views: Array[SubViewport] = []
	for mask in [1, 11]:
		var view := SubViewport.new()
		view.own_world_3d = true
		view.size = Vector2i(8, 8)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("expected_mask", mask)
		var mesh := QuadMesh.new()
		mesh.size = Vector2(4, 4)
		mesh.material = mat
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.layers = 1
		view.add_child(inst)
		var cam := Camera3D.new()
		cam.cull_mask = mask
		view.add_child(cam)
		cam.current = true
		cam.position = Vector3(0, 0, 2)
		view.set_meta("mask", mask)
		views.append(view)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for view in views:
		var px := view.get_texture().get_image().get_pixel(4, 4)
		var green := px.g > 0.9 and px.r < 0.1
		if green:
			print("PASS CAMERA_VISIBLE_LAYERS equals cull mask ", view.get_meta("mask"))
		else:
			fail("CAMERA_VISIBLE_LAYERS inequality for mask %s color %s" % [str(view.get_meta("mask")), str(px)])
		view.queue_free()

func _screen(world_x: float, world_y: float, half_w: float, half_h: float, view_size: Vector2i, camera_x: float = 0.0) -> Vector2i:
	var ndc_x := (world_x - camera_x) / half_w
	var ndc_y := (world_y - 2.0) / half_h
	var x := clampi(int((ndc_x * 0.5 + 0.5) * view_size.x), 0, view_size.x - 1)
	var y := clampi(int((1.0 - (ndc_y * 0.5 + 0.5)) * view_size.y), 0, view_size.y - 1)
	return Vector2i(x, y)

func _pixel(image: Image, at: Vector2i) -> Color:
	return image.get_pixel(at.x, at.y)

func _decode(color: Color) -> int:
	var x := clampi(int(round((color.r8 - 64) / 12.0)), 0, 15)
	var y := clampi(int(round((color.g8 - 64) / 12.0)), 0, 15)
	return x + 16 * y

func _near(color: Color, expected: Color) -> bool:
	return color.r > expected.r - 0.1 and color.r < expected.r + 0.1 \
		and color.g > expected.g - 0.1 and color.g < expected.g + 0.1 \
		and color.b > expected.b - 0.1 and color.b < expected.b + 0.1
