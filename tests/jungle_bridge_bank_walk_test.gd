extends SceneTree
## Owner r17 16-54-13 (Human and Lizard fell through the stream decks) and the r18 bisect (solid decks 223/224 stopped
## the magic-shop walks and the village escape). The shop and escape routes follow the stream bed (floor -25), and the
## deck tops stand 35-36 above it, over the 32-unit step. This walks the real route points that cross decks 223 and 224
## (tests/fixtures/magic_shop_walk.json, tests/fixtures/village_escape_route.json shop_to_gate) as Human and as Lizard
## with the grounded mover: every point must be reached, and while the body is inside a deck's footprint its feet must
## be on the deck top, not under it.
const Form := preload("res://scripts/lol2/player_form_body.gd")
const Assemblies := preload("res://scripts/lol2/static_assemblies.gd")
const DECKS: Array[int] = [223, 224]
const FORMS: Array[int] = [0, 2]
var scene
var decks: Dictionary = {}  # id -> {centre, axis, side, half_width, half_depth, top}
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL jungle bridge banks: ", message)
	quit(1)

func form_name(form: int) -> String:
	return "Human" if form == 0 else "Lizard"

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"):
			break
	if not scene.get("ready_for_review"):
		fail("Jungle not ready")
		return
	scene.set_physics_process(false)
	for i in 5:
		await physics_frame
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L4_HJ.json"))
	if not parsed is Dictionary:
		fail("Jungle collision table missing")
		return
	for id in DECKS:
		if not scene.static_assemblies.solid_bodies.has(id):
			fail("Deck %d has no solid body" % id)
			return
		var body: StaticBody3D = scene.static_assemblies.solid_bodies[id]
		if not (body.get_child(0) as CollisionShape3D).shape is ConvexPolygonShape3D:
			fail("Deck %d is not the ramped prism" % id)
			return
		var record: Dictionary = (parsed as Dictionary).boxes[str(id)]
		var yaw: float = -float(record.heading) / 65536.0 * TAU
		var basis := Basis(Vector3.UP, yaw)
		decks[id] = {"centre": Vector3(float(record.x), 0.0, -float(record.y)), "axis": basis.x, "side": basis.z,
			"half_width": float(record.width) * 0.5, "half_depth": float(record.depth) * 0.5, "top": float(record.h) + float(record.height)}
	var shop: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/magic_shop_walk.json"))
	var escape: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/village_escape_route.json"))
	var legs := {
		"223 to_shop": slice(shop.to_shop.points, 223), "223 to_monastery": slice(shop.to_monastery.points, 223),
		"224 shop_to_gate": slice(escape.routes.shop_to_gate.points, 224),
	}
	for label in legs:
		if (legs[label] as Array).size() < 3:
			fail("%s: route does not cross the deck" % label)
			return
	for form in FORMS:
		for label in legs:
			await walk_route("%s %s" % [label, form_name(form)], legs[label], form)
	if not failures.is_empty():
		fail("%d route legs failed: %s" % [failures.size(), ", ".join(failures)])
		return
	print("PASS jungle bridge banks: Human and Lizard walked the shop route over deck 223 both ways and the escape route over deck 224 on the deck tops")
	quit(0)

## Route points within 150 of the deck centre plus two points on each side.
func slice(points: Array, id: int) -> Array:
	var centre: Vector3 = decks[id].centre
	var first := -1
	var last := -1
	for i in points.size():
		if Vector2(float(points[i][0]) - centre.x, float(points[i][1]) - centre.z).length() < 150.0:
			if first < 0:
				first = i
			last = i
	if first < 0:
		return []
	return points.slice(maxi(0, first - 2), mini(points.size(), last + 3))

func deck_under(position: Vector3) -> int:
	for id in decks:
		var d: Dictionary = decks[id]
		var local: Vector3 = position - d.centre
		if absf(local.dot(d.axis)) <= d.half_width - 2.0 and absf(local.dot(d.side)) <= d.half_depth - 2.0:
			return id
	return -1

func place(at: Vector2) -> void:
	var top := Vector3(at.x, 200.0, at.y)
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top, top - Vector3.UP * 600.0, 1 | Assemblies.SCENERY_LAYER, [scene.player.get_rid()]))
	scene.player.global_position = Vector3(at.x, (float(hit.position.y) if not hit.is_empty() else 0.0) + Form.FOOT_OFFSET, at.y)
	scene.player.velocity = Vector3.ZERO
	await physics_frame

func walk_route(label: String, points: Array, form: int) -> void:
	scene.player_form = form
	if not Form.apply(scene.player, scene.camera, form, false):
		failures.append("%s form refused" % label)
		return
	await place(Vector2(float(points[0][0]), float(points[0][1])))
	var highest_on_deck := -INF
	var stood := false
	for i in range(1, points.size()):
		var to := Vector2(float(points[i][0]), float(points[i][1]))
		var reached := false
		var last: Vector3 = scene.player.global_position
		var stuck := 0
		for f in 900:
			var off := to - Vector2(scene.player.global_position.x, scene.player.global_position.z)
			if off.length() < 4.0:
				reached = true
				break
			scene.move_grounded(Vector3(off.x, 0.0, off.y).normalized(), 1.0 / 60.0)
			await physics_frame
			var feet: float = scene.player.global_position.y - Form.FOOT_OFFSET
			var over := deck_under(scene.player.global_position)
			if over >= 0:
				stood = true
				highest_on_deck = maxf(highest_on_deck, feet)
				if feet < float(decks[over].top) - 2.0:
					failures.append("%s under deck %d at %s (feet %.1f, top %.1f)" % [label, over, scene.player.global_position, feet, float(decks[over].top)])
					return
			if scene.player.global_position.distance_to(last) < 0.05:
				stuck += 1
				if stuck > 30:
					break
			else:
				stuck = 0
				last = scene.player.global_position
		if not reached:
			var p: Vector3 = scene.player.global_position
			var hits := ""
			for j in scene.player.get_slide_collision_count():
				var c: KinematicCollision3D = scene.player.get_slide_collision(j)
				hits += " %s %s" % [c.get_collider().name, c.get_normal()]
			failures.append("%s stuck before point %d %s at (%.1f, feet %.1f, %.1f)%s" % [label, i, str(points[i]), p.x, p.y - Form.FOOT_OFFSET, p.z, hits])
			return
	if not stood:
		failures.append("%s never stood on the deck" % label)
		return
	print("walked %s, highest feet on the deck %.1f" % [label, highest_on_deck])
