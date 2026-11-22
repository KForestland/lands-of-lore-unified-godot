extends SceneTree
## G-14 check tool: render a level from a list of poses, through the player's own camera.
##   godot --path . --script res://tools/render_area_poses.gd -- --start=act2-l12 --poses=POSES.json --out=DIR [--portal-off]
## Opens the level from its F2 playtest start (staged, sha-pinned save), then for each pose {"name", "x", "z", "yaw"}
## puts Luther on the highest floor under (x, z), turns him to yaw (radians) and saves DIR/<name>.png after the scene
## settles. --portal-off sets the tree meta lol2_portal_visibility_off, so the same build renders with every face drawn
## (the "before" of a portal-drawing change). Prints "POSE <name> <png>" per frame.
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
const EYE := 42.0   # camera height above the floor (the reports' camera h is floor + 42)
func _initialize() -> void: run.call_deferred()
func arg(name: String, fallback := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="): return a.trim_prefix("--" + name + "=")
	return fallback
func fail(reason: String) -> void:
	print("POSES FAILED ", reason)
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
	var layer := CanvasLayer.new(); layer.layer = 128; layer.name = "CaptionLayer"
	var label := Label.new(); label.text = text; label.position = Vector2(8, 690)
	label.add_theme_color_override("font_color", Color.YELLOW if info[1] >= 0 else Color.RED)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	layer.add_child(label); scene.add_child(layer)
	return text

func run() -> void:
	var start_id := arg("start")
	var poses = JSON.parse_string(FileAccess.get_file_as_string(arg("poses")))
	var out := arg("out")
	if not poses is Array or out.is_empty(): return fail("need --poses (array) and --out")
	if "--portal-off" in OS.get_cmdline_user_args(): set_meta("lol2_portal_visibility_off", true)
	set_meta("original_game_verified", true)
	# --meta=a,b sets tree metas before the scene loads (feature switches such as lol2_portal_visibility_off).
	for name in arg("meta").split(",", false): set_meta(name, true)
	var entry := {}
	for candidate in Starts.manifest().entries:
		if str(candidate.id) == start_id: entry = candidate
	if entry.is_empty(): return fail("unknown start " + start_id)
	var read: Dictionary = Starts.read(entry)
	if not str(read.error).is_empty(): return fail(str(read.error))
	var error: String = load("res://scripts/lol2/game_save.gd").resume_checkpoint(self, entry.area_id, read.state, true)
	if not error.is_empty(): return fail(error)
	var scene: Node = null
	for i in 1200:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("player") is Node3D and current_scene.is_node_ready():
			scene = current_scene
			break
	if scene == null: return fail("scene did not open")
	for i in 30: await physics_frame
	for node in scene.find_children("*", "CanvasLayer", true, false): node.visible = false
	DirAccess.make_dir_recursive_absolute(out)
	var regions: Array = scene.progression.regions
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	# Posing must never fire level logic (a pose in an exit region changed the level and freed the scene, L10 region 0).
	var progression_node: Variant = scene.get("progression")
	if progression_node is Node:
		(progression_node as Node).set_process(false)
		(progression_node as Node).set_physics_process(false)
	var cam := Camera3D.new()
	cam.far = 20000.0
	var player_camera: Camera3D = scene.get("camera")
	cam.fov = player_camera.fov if player_camera != null else 75.0
	scene.add_child(cam)
	for pose in poses:
		var at := Vector3(float(pose.x), 0.0, float(pose.z))
		var best := -INF
		for r in regions.size():
			var quad: Array = regions[r][0]
			if quad.size() < 3: continue
			var poly := PackedVector2Array()
			for v in quad: poly.append(Vector2(float(v[0]), float(v[1])))
			if Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), poly) and float(regions[r][1]) > best: best = float(regions[r][1])
		if best == -INF: print("POSE ", pose.name, " SKIPPED no floor"); continue
		# Luther stands on that floor (so region-based drawing sees his region); the frame comes from an independent camera
		# at floor + EYE facing yaw, so physics settling or a fall can never move the view (the first version's camera
		# could end up under the floor).
		scene.player.global_position = Vector3(at.x, best, at.z)
		scene.player.velocity = Vector3.ZERO
		scene.player.rotation.y = float(pose.get("yaw", 0.0))
		cam.global_position = Vector3(at.x, best + EYE, at.z)
		cam.global_rotation = Vector3(0.0, float(pose.get("yaw", 0.0)), 0.0)
		cam.make_current()
		for old_layer in scene.find_children("CaptionLayer*", "CanvasLayer", true, false): old_layer.queue_free()
		var cap := caption(scene, cam.global_position)
		for i in 10: await process_frame
		var image := root.get_texture().get_image()
		var path := out.path_join(str(pose.name) + ".png")
		image.save_png(path)
		print("POSE ", pose.name, " ", path, " floor ", best, " camera ", cam.global_position, " | ", cap)
	quit(0)
