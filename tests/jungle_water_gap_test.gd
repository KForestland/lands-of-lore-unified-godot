extends SceneTree
## Owner r16 F10: Jungle (-4603,-3412) and (-3408,-4454). Open bank edges show the backdrop.
## The capture poses are the report cameras. A ray whose first hit is a new water triangle is the gap closing.
const Skirts = preload("res://scripts/lol2/jungle_water_skirts.gd")
const POSES := [
	{"name": "stream", "at": Vector3(-4602.7568, 2.0406, -3411.9487), "pitch": -0.327028, "yaw": 2.770204, "region": 2559},
	{"name": "under", "at": Vector3(-3407.6865, -52.9525, -4454.0400), "pitch": -0.069009, "yaw": 0.325203, "region": 260},
]
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", message)
func _initialize() -> void:
	run.call_deferred()
func _hit(origin: Vector3, dir: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var e1 := b - a
	var e2 := c - a
	var p := dir.cross(e2)
	var det := e1.dot(p)
	if absf(det) < 0.000001: return INF
	var inv := 1.0 / det
	var tvec := origin - a
	var u := tvec.dot(p) * inv
	if u < 0.0 or u > 1.0: return INF
	var qvec := tvec.cross(e1)
	var v := dir.dot(qvec) * inv
	if v < 0.0 or u + v > 1.0: return INF
	var t := e2.dot(qvec) * inv
	return t if t > 0.05 else INF
func _nearest(origin: Vector3, dir: Vector3, tris: Array) -> float:
	var best := INF
	for item in tris:
		var tri: Array = item
		var t := _hit(origin, dir, tri[0], tri[1], tri[2])
		if t < best: best = t
	return best
func run() -> void:
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/jungle_review/jungle.json"))
	var liquid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/liquid/L4_HJ.json"))
	var planned: Array = Skirts.plan(liquid.regions, pack.faces)
	var faces := {2559: 0, 260: 0}
	for item in planned:
		var quad: Dictionary = item
		var id := int(quad.region)
		if faces.has(id): faces[id] = int(faces[id]) + 1
	check(not planned.is_empty() and int(faces[2559]) > 0 and int(faces[260]) > 0, "plan faces > 0 for regions 2559 (%d) and 260 (%d)" % [faces[2559], faces[260]])
	for pose in POSES:
		var skirts := 0
		var surfaces := 0
		for item in planned:
			var quad: Dictionary = item
			if int(quad.region) != int(pose.region): continue
			if str(quad.kind) == "skirt": skirts += 1
			if str(quad.kind) == "surface": surfaces += 1
		check(skirts >= 2 and surfaces >= 1, "%s region %d has water skirts and a surface (%d / %d)" % [pose.name, pose.region, skirts, surfaces])
	var fresh: Array = []
	var old: Array = []
	for item in planned:
		var quad: Dictionary = item
		fresh.append(quad.points)
	for face in pack.faces:
		var face_d: Dictionary = face
		if not face_d.has("points") or (face_d.points as Array).size() < 3: continue
		var pts: Array = face_d.points
		var a := Vector3(float(pts[0][0]), float(pts[0][1]), float(pts[0][2]))
		var b := Vector3(float(pts[1][0]), float(pts[1][1]), float(pts[1][2]))
		var c := Vector3(float(pts[2][0]), float(pts[2][1]), float(pts[2][2]))
		old.append([a, b, c])
		if pts.size() > 3:
			var d := Vector3(float(pts[3][0]), float(pts[3][1]), float(pts[3][2]))
			old.append([a, c, d])
	var half := tan(deg_to_rad(37.5))
	for pose in POSES:
		var basis := Basis.from_euler(Vector3(float(pose.pitch), float(pose.yaw), 0.0))
		var forward := -basis.z
		var right := basis.x
		var up := basis.y
		var origin: Vector3 = pose.at
		var closed := 0
		var cast := 0
		for iy in range(-2, 3):
			for ix in range(-3, 4):
				var dir := (forward + right * (float(ix) / 3.0 * half) + up * (float(iy) / 2.0 * half * 0.5625)).normalized()
				var near_old := INF
				for item in old:
					var tri: Array = item
					if origin.distance_squared_to((tri[0] + tri[1] + tri[2]) / 3.0) > 900.0 * 900.0: continue
					var t := _hit(origin, dir, tri[0], tri[1], tri[2])
					if t < near_old: near_old = t
				var near_new := _nearest(origin, dir, fresh)
				cast += 1
				if near_new < 700.0 and near_new + 0.5 < near_old: closed += 1
		check(closed > 0, "%s camera closes %d/%d view rays on new water" % [pose.name, closed, cast])
	var scene: Node = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	check(bool(scene.get("ready_for_review")) and scene.get_node_or_null("JungleWaterSkirts") != null, "Jungle builds the water skirts")
	scene.set_physics_process(false)
	var body: Node = scene.get("player") as Node
	if body != null: body.set_physics_process(false)
	get_root().size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("user://capture")
	var cam: Camera3D = scene.get("camera") as Camera3D
	for pose in POSES:
		cam.global_position = pose.at
		cam.rotation = Vector3(float(pose.pitch), float(pose.yaw), 0.0)
		for i in 8: await process_frame
		var image: Image = get_root().get_texture().get_image()
		var path := "user://capture/as04_%s.png" % str(pose.name)
		check(image != null and image.save_png(path) == OK, "%s capture saved" % pose.name)
		print("captured ", path, " ", image.get_width() if image != null else 0)
	scene.queue_free()
	if failures == 0: print("PASS jungle water gaps: regions 2559 and 260 gain a water surface and side skirts; both F10 cameras hit that water")
	quit(0 if failures == 0 else 1)
