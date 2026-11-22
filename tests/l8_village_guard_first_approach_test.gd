extends SceneTree
## Owner r17 18-06-16 at (554, -3929): the village guard shows up only on a later try.
## After the temple visit, the first walk to that pose must already show actor 113.
## No save and no second trip.
const Jungle := preload("res://scripts/lol2/darker_jungle.gd")
const State := preload("res://scripts/lol2/l8_journey_state.gd")
const POSE := Vector3(554.0, 32.0, -3929.0)
const GUARD := Vector3(676.0, 0.0, -4541.0)
const SLIDE := 480.0
var failures: int = 0

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL guard approach: ", label)
	return ok

func _initialize() -> void:
	run.call_deferred()

func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func walk_points(scene: Jungle, points: Array, halt: String) -> bool:
	var physics: bool = scene.is_physics_processing()
	scene.set_physics_process(false)
	var journey: Node = scene.get_node("L8Journey")
	for i in points.size():
		var point: Variant = points[i]
		if not point is Array or (point as Array).size() < 2:
			scene.set_physics_process(physics)
			return check(false, "route point %d" % i)
		var pair: Array = point
		var goal := Vector3(float(pair[0]), 0.0, float(pair[1]))
		var stuck: int = 0
		var previous: Vector3 = scene.player.position
		var allowance: int = maxi(90, int(scene.player.position.distance_to(goal) / 6.0) + 40)
		var reached: bool = false
		for _tick in allowance:
			await physics_frame
			if halt == "temple" and bool(scene.quest_state.l8_journey.temple_visited):
				scene.set_physics_process(physics)
				return true
			if halt == "pose" and Vector2(scene.player.position.x - POSE.x, scene.player.position.z - POSE.z).length() < 30.0:
				scene.set_physics_process(physics)
				return true
			var delta: Vector3 = goal - scene.player.position
			delta.y = 0.0
			if delta.length() < 14.0:
				reached = true
				break
			scene.player.velocity = delta.normalized() * SLIDE
			scene.player.velocity.y = -32.0
			scene.player.move_and_slide()
			var step: float = Vector2(scene.player.position.x - previous.x, scene.player.position.z - previous.z).length()
			previous = scene.player.position
			if step < 0.05:
				stuck += 1
			else:
				stuck = 0
			if stuck >= 8:
				scene.player.position += delta.normalized() * 6.0
				scene.player.position.y += 0.5
				stuck = 0
		if not reached:
			scene.set_physics_process(physics)
			return check(false, "walk point %d at %s toward %s" % [i, scene.player.position, halt])
		if halt == "temple" and journey.target() == "temple":
			scene.set_physics_process(physics)
			return true
	scene.set_physics_process(physics)
	return true

func guard_visible(scene: Jungle) -> bool:
	var population: Node = scene.act2_creatures
	var actor: Dictionary = population.state.actors["113"]
	var body: CharacterBody3D = population.bodies["113"]
	var material: ShaderMaterial = population.materials["113"]
	var indices: Variant = material.get_shader_parameter("indices")
	return bool(actor.present) and body.visible and indices != null and body.global_position.distance_to(GUARD) < 2.0

func run() -> void:
	var scene: Jungle = load("res://scenes/lol2/darker_jungle.tscn").instantiate() as Jungle
	if scene == null:
		check(false, "darker jungle scene")
		quit(1)
		return
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for _i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	if not scene.ready_for_review or scene.get_node_or_null("L8Journey") == null:
		check(false, "darker jungle ready")
		await stop(scene, 1)
		return
	scene.player_form = 0
	scene.flying = false
	scene.quest_state["l8_journey"] = {"version": 1, "gift": "recovered", "temple_visited": false, "admitted": false, "key_awarded": false}
	if State.BLADE not in scene.carried_collected:
		scene.carried_collected.append(State.BLADE)
	var route: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_first_departure_walk.json"))
	if not route is Dictionary:
		check(false, "walk fixture")
		await stop(scene, 1)
		return
	var village: Array = (route as Dictionary)["village"]
	# Points 55-60 step onto the guard and the trunk. The owner's look is the open ground north of them.
	var approach: Array = []
	for i in 55:
		approach.append(village[i])
	approach.append([POSE.x, POSE.z])
	# First look, before the temple. He must not already be standing there.
	scene.player.position = Vector3(POSE.x, 48.0, POSE.z)
	scene.player.velocity = Vector3.ZERO
	for _frame in 6:
		await process_frame
	if not check(not bool(scene.quest_state.l8_journey.temple_visited), "temple still ahead"):
		await stop(scene, 1)
		return
	if not check(not guard_visible(scene), "no guard on the look before the temple"):
		await stop(scene, 1)
		return
	var back: Array = []
	for i in range(54, -1, -1):
		back.append(village[i])
	back.append([758.0, 2046.0])
	if not await walk_points(scene, back, "temple"):
		await stop(scene, 1)
		return
	for _frame in 4:
		await process_frame
	if not check(bool(scene.quest_state.l8_journey.temple_visited), "temple visit committed on the walk"):
		await stop(scene, 1)
		return
	if not check(guard_visible(scene), "guard linked at the tree as soon as the temple visit commits"):
		await stop(scene, 1)
		return
	# One walk back. No reload, and this is not a second trip.
	if not await walk_points(scene, approach, "pose"):
		await stop(scene, 1)
		return
	var remain: Vector3 = POSE - scene.player.position
	remain.y = 0.0
	if remain.length() > 8.0:
		scene.set_physics_process(false)
		var allowance: int = maxi(60, int(remain.length() / 6.0) + 20)
		for _tick in allowance:
			await physics_frame
			var step: Vector3 = POSE - scene.player.position
			step.y = 0.0
			if step.length() < 8.0:
				break
			scene.player.velocity = step.normalized() * SLIDE
			scene.player.velocity.y = -32.0
			scene.player.move_and_slide()
		scene.set_physics_process(true)
	scene.player.rotation.y = -0.308
	scene.camera.rotation.x = -0.069
	await process_frame
	var flat: float = Vector2(scene.player.position.x - POSE.x, scene.player.position.z - POSE.z).length()
	if not check(flat < 30.0, "stood the owner pose at %s" % scene.player.position):
		await stop(scene, 1)
		return
	if not check(guard_visible(scene), "guard visible at the first approach %s" % scene.player.position):
		await stop(scene, 1)
		return
	if not check(not bool(scene.quest_state.l8_journey.admitted), "the blade was not shown"):
		await stop(scene, 1)
		return
	if failures == 0:
		print("PASS guard: walked the temple, then once to (554,-3929), and actor 113 was in front of the tree")
	await stop(scene, 1 if failures else 0)
