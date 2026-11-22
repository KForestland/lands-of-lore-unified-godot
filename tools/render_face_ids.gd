extends SceneTree
## G-14 standing tool: which map face is each pixel? Renders the owner's view (bundle) or a pose with every pack face the
## game currently draws re-drawn in a colour that encodes its face index, everything else hidden, then reads the image
## back and writes a legend for the faces under a rectangle.
##   bundle: godot --path . --script res://tools/render_face_ids.gd -- --bundle=REPORT_DIR --out=DIR [--rect=x0,y0,x1,y1]
##   pose:   ... -- --start=act2-l12 --pose=x,z,yaw --out=DIR [--rect=...] [--portal-off]
## A face counts as drawn when it is not excluded (owner-drawn movers, doors) and its portal batch is visible (or it has no
## batch). Owner-drawn objects, props and billboards are not in the image (their pixels read as background).
## Out: DIR/face_ids.png (false colour), DIR/legend.json and DIR/legend.md: per face under the rectangle the pixel count,
## kind, region, room (render_sector), batch cluster, material and height range. Rectangle in 1280x720 pixels; default
## the centre third of the frame. Prints "FACE IDS <dir> <faces under rect>".
const W := 1280
const H := 720
var scene: Node

func _initialize() -> void: run.call_deferred()
func arg(name: String, fallback := "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="): return a.trim_prefix("--" + name + "=")
	return fallback
func fail(reason: String) -> void:
	print("FACE IDS FAILED ", reason)
	quit(1)

func wait_scene() -> Node:
	for i in 1200:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get("player") is Node3D and current_scene.is_node_ready(): return current_scene
	return null

## Exact ids: PASSES renders, each writing 3 bits of the face id as pure black/white per channel (no colour precision
## involved). 21 bits; id 0 = background (face index + 1 is drawn).
const PASSES := 7
static func bits(id: int, pass_index: int) -> Color:
	var v := id >> (3 * pass_index)
	return Color(float(v & 1), float((v >> 1) & 1), float((v >> 2) & 1))

## Which side of a face the camera sees. A wall's front faces into its own region (the side of the region polygon's
## centre); a floor's front is seen from above, a ceiling's from below. "?" when the face has no region polygon.
func side_of(face: Dictionary, eye: Vector3) -> String:
	var kind := str(face.get("kind", ""))
	var pts: Array = face.points
	var lo := INF; var hi := -INF
	for p in pts: lo = minf(lo, float(p[1])); hi = maxf(hi, float(p[1]))
	if kind == "floor": return "front" if eye.y >= lo else "back"
	if kind == "ceiling": return "front" if eye.y <= hi else "back"
	var region: Variant = face.get("region")
	if region == null or scene.progression == null or int(region) < 0 or int(region) >= scene.progression.regions.size(): return "?"
	var quad: Array = scene.progression.regions[int(region)][0]
	if quad.size() < 3: return "?"
	var centre := Vector2.ZERO
	for v in quad: centre += Vector2(float(v[0]), float(v[1]))
	centre /= float(quad.size())
	var a := Vector2(float(pts[0][0]), float(pts[0][2])); var b := a
	for p in pts:
		var q := Vector2(float(p[0]), float(p[2]))
		if q.distance_to(a) > 0.5: b = q; break
	if b == a: return "?"
	var line := b - a
	var s_region := signf(line.cross(centre - a)); var s_eye := signf(line.cross(Vector2(eye.x, eye.z) - a))
	if s_region == 0.0 or s_eye == 0.0: return "edge-on"
	return "front" if s_region == s_eye else "back"

func run() -> void:
	set_meta("original_game_verified", true)
	# --meta=a,b sets tree metas before the scene loads (feature switches such as lol2_portal_visibility_off).
	for name in arg("meta").split(",", false): set_meta(name, true)
	if "--portal-off" in OS.get_cmdline_user_args(): set_meta("lol2_portal_visibility_off", true)
	var out := arg("out")
	if out.is_empty(): return fail("need --out")
	var camera := Camera3D.new()
	camera.far = 20000.0
	var bundle := arg("bundle")
	if not bundle.is_empty():
		var report = JSON.parse_string(FileAccess.get_file_as_string(bundle.path_join("report.json")))
		var error: String = load("res://scripts/lol2/game_save.gd").load_file(self, bundle.path_join("save.json"))
		if not error.is_empty(): return fail("load: " + error)
		scene = await wait_scene()
		if scene == null: return fail("scene did not open")
		for i in 20: await physics_frame
		var view: Dictionary = report.get("render_camera", report.get("camera", {}))
		camera.fov = float(view.get("fov", 75.0))
		scene.add_child(camera)
		camera.global_position = Vector3(view.position[0], view.position[1], view.position[2])
		camera.global_rotation = Vector3(view.rotation_radians[0], view.rotation_radians[1], view.rotation_radians[2])
	else:
		var Starts = load("res://scripts/lol2/playtest_starts.gd")
		var entry := {}
		for candidate in Starts.manifest().entries:
			if str(candidate.id) == arg("start"): entry = candidate
		if entry.is_empty(): return fail("unknown --start")
		var read: Dictionary = Starts.read(entry)
		var error: String = load("res://scripts/lol2/game_save.gd").resume_checkpoint(self, entry.area_id, read.state, true)
		if not error.is_empty(): return fail(error)
		scene = await wait_scene()
		if scene == null: return fail("scene did not open")
		for i in 20: await physics_frame
		var pose := arg("pose").split(",")
		var at := Vector3(float(pose[0]), 0.0, float(pose[1]))
		var best := -INF
		for region in scene.progression.regions:
			var quad: Array = region[0]
			if quad.size() < 3: continue
			var poly := PackedVector2Array()
			for v in quad: poly.append(Vector2(float(v[0]), float(v[1])))
			if Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), poly) and float(region[1]) > best: best = float(region[1])
		scene.set_physics_process(false)
		scene.player.set_physics_process(false)
		scene.player.global_position = Vector3(at.x, best, at.z)
		scene.player.rotation.y = float(pose[2]) if pose.size() > 2 else 0.0
		var player_camera: Camera3D = scene.get("camera")
		camera.fov = player_camera.fov if player_camera != null else 75.0
		scene.add_child(camera)
		camera.global_position = Vector3(at.x, best + 42.0, at.z)
		camera.global_rotation = Vector3(0.0, float(pose[2]) if pose.size() > 2 else 0.0, 0.0)
	camera.make_current()
	for i in 20: await process_frame   # the region walk updates batch visibility for this camera
	var data = JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
	var faces: Array = data.faces
	var verts := PackedVector3Array()
	var vert_ids := PackedInt32Array()
	var drawn := 0
	for i in faces.size():
		var face: Dictionary = faces[i]
		if not face.has("points") or (face.points as Array).size() < 3: continue
		if scene.excluded_faces.has(i): continue
		var cluster: int = scene.static_face_cluster(face)
		if cluster >= 0 and scene.cluster_meshes.has(cluster):
			var any := false
			for m in scene.cluster_meshes[cluster]:
				if is_instance_valid(m) and m.visible: any = true; break
			if not any: continue
		var pts: Array = face.points
		for t in range(1, pts.size() - 1):
			for k in [0, t, t + 1]:
				verts.append(Vector3(pts[k][0], pts[k][1], pts[k][2]))
				vert_ids.append(i + 1)
		drawn += 1
	for node in scene.find_children("*", "VisualInstance3D", true, false):
		if node is GeometryInstance3D: (node as GeometryInstance3D).visible = false
	for node in scene.find_children("*", "CanvasLayer", true, false): node.visible = false
	for node in root.find_children("*", "Control", true, false): (node as Control).visible = false
	var shader := Shader.new()
	shader.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvoid fragment() {\n\tALBEDO = COLOR.rgb;\n}\n"
	var material := ShaderMaterial.new()
	material.shader = shader
	var ids := MeshInstance3D.new()
	ids.material_override = material
	scene.add_child(ids)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	var we := WorldEnvironment.new()
	we.environment = env
	for old in scene.find_children("*", "WorldEnvironment", true, false): old.queue_free()
	scene.add_child(we)
	var id_of := PackedInt32Array()
	id_of.resize(W * H)
	var image: Image
	for p in PASSES:
		var colours := PackedColorArray()
		colours.resize(verts.size())
		for v in verts.size(): colours[v] = bits(vert_ids[v], p)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = colours
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		ids.mesh = mesh
		for i in 6: await process_frame
		image = root.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		for y in mini(H, image.get_height()):
			for x in mini(W, image.get_width()):
				var c := image.get_pixel(x, y)
				var v := (1 if c.r > 0.5 else 0) | (2 if c.g > 0.5 else 0) | (4 if c.b > 0.5 else 0)
				id_of[y * W + x] |= v << (3 * p)
	var rect := Rect2i(W / 3, H / 3, W / 3, H / 3)
	if not arg("rect").is_empty():
		var r := arg("rect").split(",")
		rect = Rect2i(int(r[0]), int(r[1]), int(r[2]) - int(r[0]), int(r[3]) - int(r[1]))
	var counts := {}
	var colour_view := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGB8)
	for y in mini(H, image.get_height()):
		for x in mini(W, image.get_width()):
			var id := id_of[y * W + x] - 1
			if id >= 0 and id < faces.size():
				var hue := fmod(float(id) * 0.61803398875, 1.0)
				colour_view.set_pixel(x, y, Color.from_hsv(hue, 0.65, 0.95))
				if rect.has_point(Vector2i(x, y)): counts[id] = int(counts.get(id, 0)) + 1
	for x in range(rect.position.x, rect.end.x):
		colour_view.set_pixel(x, rect.position.y, Color.WHITE); colour_view.set_pixel(x, rect.end.y - 1, Color.WHITE)
	for y in range(rect.position.y, rect.end.y):
		colour_view.set_pixel(rect.position.x, y, Color.WHITE); colour_view.set_pixel(rect.end.x - 1, y, Color.WHITE)
	DirAccess.make_dir_recursive_absolute(out)
	colour_view.save_png(out.path_join("face_ids.png"))
	var ids_sorted := counts.keys()
	ids_sorted.sort_custom(func(a, b): return counts[a] > counts[b])
	var rows := []
	var md := ["| Face | Pixels | Kind | Side | Region | Room | Batch | Material | Height |", "|---|---|---|---|---|---|---|---|---|"]
	for id in ids_sorted:
		var face: Dictionary = faces[id]
		var lo := INF; var hi := -INF
		for p in face.points: lo = minf(lo, float(p[1])); hi = maxf(hi, float(p[1]))
		var side := side_of(face, camera.global_position)
		var row := {"face": id, "pixels": counts[id], "kind": face.get("kind"), "region": face.get("region"), "side": side,
			"room": face.get("render_sector"), "batch": scene.static_face_cluster(face), "material": face.get("material"),
			"placement": face.get("placement"), "height": [lo, hi]}
		rows.append(row)
		md.append("| %d | %d | %s | %s | %s | %s | %s | %s | %d..%d |" % [id, counts[id], str(row.kind), side, str(row.region), str(row.room), str(row.batch), str(row.material), int(lo), int(hi)])
	var legend := {"one_sided_walls": scene.get("one_sided_walls"), "scene": scene.scene_file_path, "area": scene.get("area_id"), "camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
		"rect": [rect.position.x, rect.position.y, rect.end.x, rect.end.y], "faces_drawn": drawn, "faces": rows}
	var f := FileAccess.open(out.path_join("legend.json"), FileAccess.WRITE); f.store_string(JSON.stringify(legend, "\t") + "\n"); f.close()
	f = FileAccess.open(out.path_join("legend.md"), FileAccess.WRITE); f.store_string("\n".join(md) + "\n"); f.close()
	print("FACE IDS ", out, " ", rows.size(), " faces under rect, ", drawn, " drawn")
	quit(0)
