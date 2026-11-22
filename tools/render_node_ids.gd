extends SceneTree
## G-14 standing tool: which scene NODE draws each pixel? Like render_face_ids.gd, but every visible mesh node
## (MeshInstance3D, MultiMeshInstance3D: static batches, owner-drawn movers, props, sky ceilings, ...) gets one id, drawn
## in 7 black/white bit passes (exact). Use it when a pixel is not a pack face (render_face_ids shows background there).
##   godot --path . --script res://tools/render_node_ids.gd -- --bundle=REPORT_DIR --out=DIR [--rect=x0,y0,x1,y1] [--meta=a,b]
## Out: DIR/legend.md / legend.json: per node under the rectangle, pixels, node path, class, script, mesh AABB.
const W := 1280
const H := 720
const PASSES := 7
func _initialize() -> void: run.call_deferred()
func arg(name: String, fallback := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="): return a.trim_prefix("--" + name + "=")
	return fallback
func fail(reason: String) -> void:
	print("NODE IDS FAILED ", reason)
	quit(1)
func run() -> void:
	set_meta("original_game_verified", true)
	for name in arg("meta").split(",", false): set_meta(name, true)
	var bundle := arg("bundle")
	var out := arg("out")
	var report = JSON.parse_string(FileAccess.get_file_as_string(bundle.path_join("report.json")))
	var error: String = load("res://scripts/lol2/game_save.gd").load_file(self, bundle.path_join("save.json"))
	if not error.is_empty(): return fail(error)
	var scene: Node = null
	for i in 1200:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("player") is Node3D and current_scene.is_node_ready(): scene = current_scene; break
	if scene == null: return fail("scene did not open")
	for i in 20: await physics_frame
	var view: Dictionary = report.get("render_camera", report.get("camera", {}))
	var camera := Camera3D.new()
	camera.fov = float(view.get("fov", 75.0)); camera.far = 20000.0
	scene.add_child(camera)
	camera.global_position = Vector3(view.position[0], view.position[1], view.position[2])
	camera.global_rotation = Vector3(view.rotation_radians[0], view.rotation_radians[1], view.rotation_radians[2])
	camera.make_current()
	for i in 20: await process_frame
	scene.set_process(false)
	for child in scene.get_children(): child.set_process(false)   # freeze visibility/animation while the passes render
	var nodes: Array = []
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if (node as GeometryInstance3D).is_visible_in_tree(): nodes.append(node)
	for node in root.find_children("*", "Control", true, false): (node as Control).visible = false
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform vec3 id_bits = vec3(0.0);\nvoid fragment() { ALBEDO = id_bits; }\n"
	var mats: Array = []
	for i in nodes.size():
		var m := ShaderMaterial.new(); m.shader = shader
		(nodes[i] as GeometryInstance3D).material_override = m
		mats.append(m)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color.BLACK
	for old in root.find_children("*", "WorldEnvironment", true, false): old.queue_free()
	var we := WorldEnvironment.new(); we.environment = env; scene.add_child(we)
	var id_of := PackedInt32Array(); id_of.resize(W * H)
	for p in PASSES:
		for i in nodes.size():
			var v := (i + 1) >> (3 * p)
			(mats[i] as ShaderMaterial).set_shader_parameter("id_bits", Vector3(float(v & 1), float((v >> 1) & 1), float((v >> 2) & 1)))
		for k in 6: await process_frame
		var image := root.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		for y in mini(H, image.get_height()):
			for x in mini(W, image.get_width()):
				var c := image.get_pixel(x, y)
				id_of[y * W + x] |= ((1 if c.r > 0.5 else 0) | (2 if c.g > 0.5 else 0) | (4 if c.b > 0.5 else 0)) << (3 * p)
	var rect := Rect2i(0, 0, W, H)
	if not arg("rect").is_empty():
		var r := arg("rect").split(",")
		rect = Rect2i(int(r[0]), int(r[1]), int(r[2]) - int(r[0]), int(r[3]) - int(r[1]))
	var counts := {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var id := id_of[y * W + x] - 1
			if id >= 0 and id < nodes.size(): counts[id] = int(counts.get(id, 0)) + 1
	var keys := counts.keys(); keys.sort_custom(func(a, b): return counts[a] > counts[b])
	var rows := []; var md := ["| Pixels | Node | Class | Script | AABB |", "|---|---|---|---|---|"]
	for id in keys:
		var n: GeometryInstance3D = nodes[id]
		var script_path := str(n.get_script().resource_path) if n.get_script() != null else ""
		var parent_script := str(n.get_parent().get_script().resource_path) if n.get_parent() != null and n.get_parent().get_script() != null else ""
		var box := n.global_transform * n.get_aabb()
		rows.append({"pixels": counts[id], "node": str(n.get_path()), "class": n.get_class(), "script": script_path, "parent_script": parent_script, "aabb": [box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z]})
		md.append("| %d | %s | %s | %s | %s |" % [counts[id], str(n.get_path()), n.get_class(), script_path if not script_path.is_empty() else parent_script, str(box)])
	DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open(out.path_join("legend.json"), FileAccess.WRITE); f.store_string(JSON.stringify({"rect": [rect.position.x, rect.position.y, rect.end.x, rect.end.y], "nodes": rows}, "\t") + "\n"); f.close()
	f = FileAccess.open(out.path_join("legend.md"), FileAccess.WRITE); f.store_string("\n".join(md) + "\n"); f.close()
	print("NODE IDS ", out, " ", rows.size(), " nodes under rect of ", nodes.size(), " visible")
	quit(0)
