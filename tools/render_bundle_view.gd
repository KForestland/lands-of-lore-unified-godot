extends SceneTree
## G-14 proof tool: render the owner's exact view from an F10 bundle.
##   godot --path . --script res://tools/render_bundle_view.gd -- --bundle=REPORT_DIR --out=FRAME.png [--frames=30]
## Loads REPORT_DIR/save.json through game_save.load_file (same validation and scene path as a slot), then places a camera
## at the report's drawn camera (render_camera, else camera: Godot global position + rotation, fov) and saves one frame.
## Luther stays at the saved pose, so region-based drawing (portal visibility, islands) sees the same player region the
## owner had. Run on a private display (Xvfb); prints "BUNDLE VIEW <png>" or "BUNDLE VIEW FAILED <reason>".
func _initialize() -> void: run.call_deferred()
func arg(name: String, fallback := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="): return a.trim_prefix("--" + name + "=")
	return fallback
func fail(reason: String) -> void:
	print("BUNDLE VIEW FAILED ", reason)
	quit(1)
## Standing rule (lead 2026-11-12): every proof frame carries the camera's height above the floor under it, and a frame
## from below every floor is flagged. Returns [height above the highest floor at or below the camera, region] or
## [NAN, -1] when no floor lies below (camera under the ground).
func camera_floor(scene: Node, eye: Vector3) -> Array:
	var best := -INF; var region := -1
	if scene.get("progression") == null: return [NAN, -1]
	var regions: Array = scene.progression.regions
	for r in regions.size():
		var quad: Array = regions[r][0]
		if quad.size() < 3: continue
		var poly := PackedVector2Array()
		for v in quad: poly.append(Vector2(float(v[0]), float(v[1])))
		var f := float(regions[r][1])
		if f <= eye.y + 0.5 and f > best and Geometry2D.is_point_in_polygon(Vector2(eye.x, eye.z), poly): best = f; region = r
	return [eye.y - best, region] if region >= 0 else [NAN, -1]

func caption(scene: Node, eye: Vector3) -> String:
	var info := camera_floor(scene, eye)
	var text := "camera %+.0f above floor (region %d)" % [info[0], info[1]] if info[1] >= 0 else "WARNING: camera below every floor"
	var layer := CanvasLayer.new(); layer.layer = 128
	var label := Label.new(); label.text = text; label.position = Vector2(8, 690)
	label.add_theme_color_override("font_color", Color.YELLOW if info[1] >= 0 else Color.RED)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(label); scene.add_child(layer)
	return text

func run() -> void:
	var bundle := arg("bundle")
	var out := arg("out")
	var settle := int(arg("frames", "30"))
	if bundle.is_empty() or out.is_empty(): return fail("need --bundle and --out")
	var report = JSON.parse_string(FileAccess.get_file_as_string(bundle.path_join("report.json")))
	if not report is Dictionary: return fail("report.json unreadable")
	set_meta("original_game_verified", true)
	# --meta=a,b sets tree metas before the scene loads (feature switches such as lol2_portal_visibility_off).
	for name in arg("meta").split(",", false): set_meta(name, true)
	var error: String = load("res://scripts/lol2/game_save.gd").load_file(self, bundle.path_join("save.json"))
	if not error.is_empty(): return fail("load: " + error)
	var scene: Node = null
	for i in 1200:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("player") is Node3D and current_scene.is_node_ready():
			scene = current_scene
			break
	if scene == null: return fail("scene did not open")
	for i in 20: await physics_frame
	var view: Dictionary = report.get("render_camera", report.get("camera", {}))
	if not view.has("position"): return fail("report has no camera")
	var camera := Camera3D.new()
	camera.fov = float(view.get("fov", 75.0))
	camera.far = 20000.0
	scene.add_child(camera)
	camera.global_position = Vector3(view.position[0], view.position[1], view.position[2])
	camera.global_rotation = Vector3(view.rotation_radians[0], view.rotation_radians[1], view.rotation_radians[2])
	camera.make_current()
	# Hide the HUD layers so the frame shows only the world, like the owner's 3D view.
	for node in scene.find_children("*", "CanvasLayer", true, false): node.visible = false
	# --hide=Prefix1,Prefix2 hides 3D nodes whose name starts with a prefix (which mesh draws a pixel?).
	for prefix in arg("hide").split(",", false):
		for node in scene.find_children(prefix + "*", "Node3D", true, false): node.visible = false
	var cap := caption(scene, camera.global_position)
	for i in settle: await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty(): return fail("no frame (headless?)")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	if image.save_png(out) != OK: return fail("cannot write " + out)
	var vis_node: Node = scene.get("region_visibility")
	var joined := str(vis_node.overlap_joined) if vis_node != null else "-"
	print("BUNDLE VIEW ", out, " area ", scene.get("area_id"), " camera ", camera.global_position, " | ", cap, " | overlap edges joined ", joined)
	quit(0)
