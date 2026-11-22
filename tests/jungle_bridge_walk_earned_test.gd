extends SceneTree
## Owner r17 16-54-13, map about (-3731,-2083): "all the bridges have no collisions".
## The grey sheet under that bridge was the withdrawn AV04 water. Walk every Jungle
## bridge as Human and as Lizard: the material-0655 slabs 219, 221, 222, 223, 224
## and 227, then the river plank chain 213-214-210-212. A deck that does not hold
## the feet fails. Human and Lizard must not break plank 210.
const Form := preload("res://scripts/lol2/player_form_body.gd")
const SLABS: Array[int] = [219, 221, 222, 223, 224, 227]
const FORMS: Array[int] = [0, 2]
var scene
var misses: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL jungle bridges: ", message)
	quit(1)

func miss(message: String) -> void:
	misses.append(message)
	print("OPEN ", message)

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
	# The review host also slides the body. This walk drives move_grounded itself.
	scene.set_physics_process(false)
	for i in 5:
		await physics_frame
	for id in SLABS:
		if not scene.static_assemblies.solid_bodies.has(id):
			fail("Deck %d has no solid box" % id)
			return
	for id in scene.JUNGLE_BRIDGE:
		if not scene.static_assemblies.solid_bodies.has(id):
			fail("River plank %d has no solid box" % id)
			return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/static_collision_L4_HJ.json"))
	if not parsed is Dictionary:
		fail("Jungle collision table missing")
		return
	var rows: Dictionary = (parsed as Dictionary).boxes
	for id in SLABS:
		var record: Dictionary = rows[str(id)]
		var yaw: float = -float(record.heading) / 65536.0 * TAU
		var axis: Vector3 = Basis(Vector3.UP, yaw).x
		var top: float = float(record.h) + float(record.height)
		var center := Vector3(float(record.x), top, -float(record.y))
		var reach: float = float(record.width) * 0.5 - 24.0
		if reach < 12.0:
			fail("Deck %d is too short to walk" % id)
			return
		for form in FORMS:
			await cross("%d %s" % [id, form_name(form)], center - axis * reach, center + axis * reach, top, form)
	for form in FORMS:
		await cross("river %s" % form_name(form), Vector3(760.0, 0.0, 1207.0), Vector3(1950.0, 0.0, 1207.0), 0.0, form)
	if not misses.is_empty():
		fail("%d crossings fell through" % misses.size())
		return
	var bridge: Variant = scene.get("plank_bridge")
	if bridge != null and bool(bridge.broken()):
		fail("Human and Lizard broke the river plank")
		return
	print("PASS jungle bridges: Human and Lizard crossed slabs 219, 221, 222, 223, 224, 227 and the river plank chain")
	quit(0)

func cross(label: String, start: Vector3, end_at: Vector3, top: float, form: int) -> bool:
	scene.player_form = form
	var body: CharacterBody3D = scene.player
	if not Form.apply(body, scene.camera, form, false):
		miss("%s form refused" % label)
		return false
	body.global_position = start + Vector3.UP * 36.0
	body.velocity = Vector3.ZERO
	for i in 20:
		await physics_frame
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		_tick_bridge()
	var feet: float = body.global_position.y - Form.FOOT_OFFSET
	if feet < top - 12.0:
		miss("%s fell on the step-on (feet %.1f, deck %.1f) at %s" % [label, feet, top, body.global_position])
		return false
	var target := Vector2(end_at.x, end_at.z)
	var stuck := 0
	var previous := body.global_position
	var limit: int = int(start.distance_to(end_at) / 80.0 * 60.0) + 120
	for i in limit:
		var flat := target - Vector2(body.global_position.x, body.global_position.z)
		if flat.length() < 6.0:
			break
		await physics_frame
		scene.move_grounded(Vector3(flat.x, 0.0, flat.y).normalized(), 1.0 / 60.0)
		_tick_bridge()
		feet = body.global_position.y - Form.FOOT_OFFSET
		if feet < top - 12.0:
			miss("%s fell through (feet %.1f, deck %.1f) at %s" % [label, feet, top, body.global_position])
			return false
		if body.global_position.distance_to(previous) < 0.05:
			stuck += 1
			if stuck >= 25:
				miss("%s stuck at %s, %.1f from the far end" % [label, body.global_position, flat.length()])
				return false
		else:
			stuck = 0
			previous = body.global_position
	var left: float = (target - Vector2(body.global_position.x, body.global_position.z)).length()
	if left >= 6.0:
		miss("%s stopped %.1f short at %s" % [label, left, body.global_position])
		return false
	print("crossed %s feet %.1f" % [label, body.global_position.y - Form.FOOT_OFFSET])
	return true

func _tick_bridge() -> void:
	var bridge: Variant = scene.get("plank_bridge")
	if bridge != null:
		bridge.advance()
