extends SceneTree
## Owner r17 streams. Walk onto region 2559, where the only new mesh is a material-808
## surface, and under a water surface (region 260's camera, then a deep river on foot):
## tint, fog, muffled bus. The clock sinks Luther and death slides. No skirt walls.
const Liquid = preload("res://scripts/lol2/liquid_drowning.gd")
const Form = preload("res://scripts/lol2/player_form_body.gd")
const Surface = preload("res://scripts/lol2/jungle_stream_surface.gd")
const STREAM := Vector3(-4602.7568, 2.0406, -3411.9487)
const STREAM_PITCH := -0.327028
const STREAM_YAW := 2.770204
const UNDER := Vector3(-3407.6865, -52.9525, -4454.0400)
const UNDER_PITCH := -0.069009
const UNDER_YAW := 0.325203
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func centroid(region: Dictionary) -> Vector2:
	var poly: PackedVector2Array = region.polygon
	var c := Vector2.ZERO
	for p in poly: c += p
	return c / float(poly.size())

func inside(region: Dictionary, at: Vector3) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), region.polygon)

func _hit(origin: Vector3, dir: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var e1 := b - a
	var e2 := c - a
	var pvec := dir.cross(e2)
	var det := e1.dot(pvec)
	if absf(det) < 0.000001: return INF
	var inv := 1.0 / det
	var tvec := origin - a
	var u := tvec.dot(pvec) * inv
	if u < 0.0 or u > 1.0: return INF
	var qvec := tvec.cross(e1)
	var v := dir.dot(qvec) * inv
	if v < 0.0 or u + v > 1.0: return INF
	var t := e2.dot(qvec) * inv
	return t if t > 0.05 else INF

func hits_surface(mesh: MeshInstance3D, origin: Vector3, dir: Vector3) -> bool:
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var xform := mesh.global_transform
	for i in range(0, verts.size(), 3):
		var a := xform * verts[i]
		var b := xform * verts[i + 1]
		var c := xform * verts[i + 2]
		if _hit(origin, dir, a, b, c) < 800.0: return true
	return false

func spread(image: Image) -> float:
	var acc := 0.0
	var acc2 := 0.0
	var n := 0
	var w := image.get_width()
	var h := image.get_height()
	for y in range(maxi(h / 2 - 20, 0), mini(h / 2 + 20, h)):
		for x in range(maxi(w / 2 - 20, 0), mini(w / 2 + 20, w)):
			var red := image.get_pixel(x, y).r
			acc += red
			acc2 += red * red
			n += 1
	if n == 0: return 0.0
	var mean := acc / float(n)
	return sqrt(maxf(acc2 / float(n) - mean * mean, 0.0))

func average(image: Image) -> Vector3:
	var acc := Vector3.ZERO
	var n := 0
	var w := image.get_width()
	var h := image.get_height()
	for y in range(0, h, 8):
		for x in range(0, w, 8):
			var pixel := image.get_pixel(x, y)
			acc += Vector3(pixel.r, pixel.g, pixel.b)
			n += 1
	return acc / float(n)

func shot(path: String) -> Image:
	for i in 4: await process_frame
	var image := root.get_texture().get_image()
	if image != null:
		image.save_png(path)
	return image

func walk_to(scene: Node, target: Vector3, floor_y: float) -> Vector3:
	var host = scene
	var body := host.player as CharacterBody3D
	var stuck := 0
	for _i in 240:
		var here := body.global_position
		if here.y < floor_y - 50.0: break
		var flat := Vector2(target.x - here.x, target.z - here.z)
		if flat.length() < 6.0: break
		var before := here
		host.move_grounded(Vector3(flat.x, 0.0, flat.y).normalized(), 1.0 / 60.0)
		var moved := Vector2(body.global_position.x - before.x, body.global_position.z - before.z).length()
		if moved < 0.05: stuck += 1
		else: stuck = 0
		if stuck >= 22: break
	return body.global_position

func approaches(region: Dictionary) -> Array:
	var poly: PackedVector2Array = region.polygon
	var centre := centroid(region)
	var floor_y := float(region.floor) + Form.FOOT_OFFSET + 6.0
	var out: Array = []
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		var mid := (a + b) * 0.5
		var edge := b - a
		if edge.length() < 1.0: continue
		var n := Vector2(-edge.y, edge.x).normalized()
		if n.dot(centre - mid) > 0.0: n = -n
		var p := mid + n * 28.0
		out.append(Vector3(p.x, floor_y, p.y))
	var inset := poly[0].lerp(centre, 0.2)
	out.append(Vector3(inset.x, floor_y, inset.y))
	return out

func on_bed(region: Dictionary, at: Vector3) -> bool:
	var bed := float(region.floor) + Form.FOOT_OFFSET
	return inside(region, at) and absf(at.y - bed) < 8.0

func walk_in(scene: Node, region: Dictionary) -> Vector3:
	var host = scene
	var body := host.player as CharacterBody3D
	var centre := centroid(region)
	var bed := float(region.floor) + Form.FOOT_OFFSET
	var goal := Vector3(centre.x, bed, centre.y)
	var landed := body.global_position
	for start in approaches(region):
		body.global_position = start
		body.velocity = Vector3.ZERO
		landed = walk_to(scene, goal, bed)
		if on_bed(region, landed): return landed
	var poly: PackedVector2Array = region.polygon
	for i in poly.size():
		var inset: Vector2 = (poly[i] as Vector2).lerp(centre, 0.35)
		var across: Vector2 = centre.lerp(poly[(i + 1) % poly.size()], 0.35)
		body.global_position = Vector3(inset.x, bed + 2.0, inset.y)
		body.velocity = Vector3.ZERO
		landed = walk_to(scene, Vector3(across.x, bed, across.y), bed)
		if on_bed(region, landed) and Vector2(landed.x - inset.x, landed.z - inset.y).length() > 4.0: return landed
	return landed

func run() -> void:
	check(Liquid.SINK_SPEED <= 8.0 and Liquid.SLIDE_SPEED < 40.0 and Liquid.State.LIMIT == 15.0, "sink is slow, the slide is not a drop, and LIMIT stays 15")
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in 8: await process_frame
	if scene.has_method("set_development_mode"): scene.set_development_mode(false)
	scene.set_physics_process(false)
	var liquid = scene.liquid_drowning
	check(liquid != null and liquid.regions.size() == 810, "Jungle still has 810 water regions")
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/liquid/L4_HJ.json"))
	var by_id := {}
	for row in pack.regions:
		by_id[int(row.region)] = row
	var changed := 0
	var stream_region: Dictionary = {}
	var under_region: Dictionary = {}
	for item in liquid.regions:
		var region: Dictionary = item
		var src: Dictionary = by_id[int(region.id)]
		if not is_equal_approx(float(region.floor), float(src.floor)) or not is_equal_approx(float(region.surface), float(src.surface)):
			changed += 1
		if int(region.id) == Surface.REGION: stream_region = region
		if int(region.id) == 260: under_region = region
	check(changed == 0 and not stream_region.is_empty() and not under_region.is_empty(), "no water column changed; 2559 and 260 are still the r16 beds")
	check(is_equal_approx(float(stream_region.floor), -20.0) and is_equal_approx(float(stream_region.surface), -5.0), "region 2559 bed -20 surface -5")
	check(is_equal_approx(float(under_region.floor), -20.0) and is_equal_approx(float(under_region.surface), -15.0), "region 260 bed -20 surface -15, and it gets no new mesh")
	var sheets := 0
	var skirts := 0
	var stack: Array = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var node_name := str(node.name)
		if node_name.begins_with("WaterSkirt") or node_name == "JungleWaterSkirts": skirts += 1
		if node_name.begins_with("WaterSurface"): sheets += 1
		for child in node.get_children(): stack.append(child)
	check(sheets == 1 and skirts == 0, "one water surface and no skirt walls (%d / %d)" % [sheets, skirts])
	var mesh := scene.get_node_or_null("JungleStreamSurface/WaterSurface2559") as MeshInstance3D
	var real: Variant = scene.materials.get("808")
	var mat: Material = mesh.get_active_material(0) if mesh != null else null
	check(mesh != null and mat is StandardMaterial3D and real is StandardMaterial3D, "region 2559 uses a StandardMaterial3D")
	if mat is StandardMaterial3D and real is StandardMaterial3D:
		var sheet := mat as StandardMaterial3D
		var water := real as StandardMaterial3D
		check(sheet.albedo_texture != null and sheet.albedo_texture == water.albedo_texture, "the sheet uses material 808's texture, not a grey fallback")
	root.size = Vector2i(640, 360)
	scene.player_form = 0
	Form.apply(scene.player, scene.camera, 0, false)
	var walked: Vector3 = walk_in(scene, stream_region)
	check(on_bed(stream_region, walked), "Human walked onto the region 2559 bed at %s" % walked)
	var above := Vector3(walked.x, float(stream_region.surface) + 8.0, walked.z)
	check(mesh != null and hits_surface(mesh, above, Vector3.DOWN), "a downward look hits the new surface")
	DirAccess.make_dir_recursive_absolute("/tmp/bg06-captures")
	var cam := scene.camera as Camera3D
	cam.global_position = above
	cam.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	var down := await shot("/tmp/bg06-captures/surface_down.png")
	check(down != null and spread(down) > 0.015, "the surface capture is the water texture, not a flat grey sheet (spread %s)" % (spread(down) if down != null else -1))
	var view = liquid.water_view
	check(view != null and not view.underwater, "standing above region 2559 is not the underwater view")
	cam.global_position = STREAM
	cam.rotation = Vector3(STREAM_PITCH, STREAM_YAW, 0.0)
	for i in 6: await process_frame
	var stream_shot := await shot("/tmp/bg06-captures/r16_stream.png")
	check(stream_shot != null and not view.underwater, "r16 stream camera stays above the surface")
	cam.global_position = UNDER
	cam.rotation = Vector3(UNDER_PITCH, UNDER_YAW, 0.0)
	for i in 6: await process_frame
	check(view.underwater and view.tint.visible and view.muffled(), "r16 under camera: tint and muffled bus")
	var env := view.environment as Environment
	check(env != null and env.fog_enabled and is_equal_approx(env.fog_density, view.FOG_DENSITY), "r16 under camera: blue-green fog")
	var under_on := await shot("/tmp/bg06-captures/r16_under.png")
	view.set_process(false)
	view._apply(false)
	for i in 3: await process_frame
	var under_off := await shot("/tmp/bg06-captures/r16_under_clear.png")
	check(under_on != null and under_off != null, "both r16 under captures saved")
	if under_on != null and under_off != null:
		var on_avg := average(under_on)
		var off_avg := average(under_off)
		check(on_avg.y + on_avg.z > off_avg.y + off_avg.z + 0.01, "the under-surface tint shifts the picture blue-green")
	view.underwater = false
	view.set_process(true)
	cam.position = Vector3(0, 10, 0)
	cam.rotation = Vector3.ZERO
	for i in 4: await process_frame
	var deep: Dictionary = {}
	for item in liquid.regions:
		var region: Dictionary = item
		var depth := float(region.surface) - float(region.floor)
		if depth >= 85.0 and depth <= 140.0 and not region.bit0 and (region.polygon as PackedVector2Array).size() >= 3:
			if deep.is_empty() or (region.polygon as PackedVector2Array).size() == 4: deep = region
	check(not deep.is_empty(), "a deep river exists so a walking Human goes under")
	if not deep.is_empty():
		var stood: Vector3 = walk_in(scene, deep)
		check(on_bed(deep, stood), "Human walked onto the deep river bed at %s" % stood)
		Form.apply(scene.player, scene.camera, 0, false)
		for i in 4: await process_frame
		var eye := (scene.camera as Camera3D).global_position
		var stood_now := (scene.player as CharacterBody3D).global_position
		check(eye.y < float(deep.surface), "walked eye %s body %s is below surface %.1f" % [eye, stood_now, float(deep.surface)])
		check(view.underwater and view.tint.visible and view.muffled(), "walked-in tint and muffle (under %s eye %s)" % [view.underwater, eye])
		liquid.set_physics_process(false)
		var body := scene.player as CharacterBody3D
		body.velocity = Vector3.ZERO
		var bed := float(deep.floor) + Form.FOOT_OFFSET
		body.global_position = Vector3(stood.x, bed + 10.0, stood.z)
		scene.starting_magic.set_health(30)
		liquid.drowning.reset()
		liquid.settle_ready = false
		var before := body.global_position.y
		liquid.tick(1.0, 1)
		var dropped := before - body.global_position.y
		check(dropped > 4.0 and dropped < 9.0 and body.global_position.y > bed + 1.0, "one second under sinks about %s units, not to the bed (%.2f)" % [Liquid.SINK_SPEED, dropped])
		check(liquid.drowning.active and liquid.overlay.shown_ratio > 0.05, "the rising veil stays on the clock")
		liquid.settle_y = bed + 18.0
		liquid.settle_ready = true
		body.global_position.y = bed + 18.0 - 30.0
		body.velocity = Vector3(0, -180, 0)
		liquid.drowning.active = true
		liquid._settle(0.5, deep, true, true)
		var corrected := bed + 18.0 - body.global_position.y
		check(corrected > 2.0 and corrected < 5.0, "a physics drop is pulled back to the slow sink (%.2f)" % corrected)
		body.global_position = Vector3(stood.x, bed + 30.0, stood.z)
		body.velocity = Vector3.ZERO
		liquid.drowning.elapsed = 14.6
		liquid.drowning.active = true
		liquid.drowning.dead = false
		liquid.settle_ready = false
		liquid.tick(0.5, 1)
		check(liquid.drowning.dead and scene.starting_magic.health() == 0, "the clock still drowns")
		var gap := body.global_position.y - bed
		check(gap > 6.0, "death does not drop Luther onto the bed in one step (still %.1f up)" % gap)
		var steps := 0
		while body.global_position.y > bed + 0.2 and steps < 8:
			var high := body.global_position.y
			liquid.tick(0.4, 1)
			var step := high - body.global_position.y
			check(step < Liquid.SLIDE_SPEED * 0.4 + 1.0, "death slide step %.2f" % step)
			steps += 1
		check(steps >= 2 and body.global_position.y <= bed + 0.6, "death reaches the bed as a slide (%d steps)" % steps)
		check(is_equal_approx(liquid.overlay.shown_ratio, 1.0), "the veil is full at death")
	if failures == 0:
		print("PASS earned water: Human walked onto region 2559 and the material 808 surface is the only new mesh; the under-surface camera gets tint, fog, and a muffled bus; Luther sinks with the clock and slides on death")
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
