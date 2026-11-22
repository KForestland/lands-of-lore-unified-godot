extends SceneTree
## Owner r17 16-36-49/16-36-57 at Museum (2557, 20): the ceiling dust pile looked
## worn away. Walk to that spot and look up. Flag 0x80 hangs upright in the gap
## under the ceiling (template 13, anchor 80, top 10, ceiling 90). The row flip stays.
const DUST := 347
const CEILING_Y := 90.0
var scene

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL ceiling dust: ", message)
	quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"):
			break
	if not scene.get("ready_for_review"):
		fail("Museum not ready")
		return
	scene.set_physics_process(false)
	if is_instance_valid(scene.sword_transfer):
		scene.sword_transfer.set_process(false)
	var body: CharacterBody3D = scene.player
	body.global_position = Vector3(2700.0, 80.0, 20.0)
	body.velocity = Vector3.ZERO
	if not await walk_to(Vector2(2557.0, 20.0)):
		return
	var dust: MeshInstance3D = scene.museum_props.get_node("MuseumProp_%d" % DUST)
	var mat := dust.material_override as StandardMaterial3D
	var quad := dust.mesh as QuadMesh
	var world: AABB = dust.global_transform * dust.get_aabb()
	var top: float = world.position.y + world.size.y
	if not is_equal_approx(dust.rotation.x, 0.0) or mat.billboard_mode != BaseMaterial3D.BILLBOARD_FIXED_Y:
		fail("Pile is not an upright hang at %s rotation %s" % [dust.global_position, dust.rotation])
		return
	if not is_equal_approx(mat.uv1_scale.y, -1.0):
		fail("Row flip is gone")
		return
	if world.size.y < quad.size.y * 0.8 or top > CEILING_Y + 0.5 or world.position.y > CEILING_Y - 8.0:
		fail("Pile does not hang under the ceiling aabb %s" % world)
		return
	var center: Vector3 = world.get_center()
	scene.camera.look_at(center, Vector3.UP)
	var forward: Vector3 = -scene.camera.global_basis.z
	var delta: Vector3 = center - scene.camera.global_position
	if delta.length() < 0.01 or forward.dot(delta.normalized()) < 0.99:
		fail("Look missed the pile at %s from %s" % [center, body.global_position])
		return
	var stood := Vector2(body.global_position.x, body.global_position.z)
	if stood.distance_to(Vector2(2557.0, 20.0)) > 8.0:
		fail("Did not stay at the owner spot %s" % body.global_position)
		return
	print("PASS ceiling dust: walked to (2557,20), looked up, and the pile hangs under the ceiling")
	quit(0)

func walk_to(target: Vector2) -> bool:
	var body: CharacterBody3D = scene.player
	var stuck := 0
	var previous := body.global_position
	for i in 500:
		var flat := target - Vector2(body.global_position.x, body.global_position.z)
		if flat.length() < 6.0:
			return true
		await physics_frame
		step(Vector3(flat.x, 0.0, flat.y).normalized())
		if body.global_position.y < -40.0:
			fail("Fell on the way to %s at %s" % [target, body.global_position])
			return false
		if body.global_position.distance_to(previous) < 0.05:
			stuck += 1
			if stuck >= 25:
				fail("Stuck on the way to %s at %s" % [target, body.global_position])
				return false
		else:
			stuck = 0
			previous = body.global_position
	var left: float = (target - Vector2(body.global_position.x, body.global_position.z)).length()
	fail("Stopped %.1f short of %s at %s" % [left, target, body.global_position])
	return false

func step(dir: Vector3) -> void:
	var body: CharacterBody3D = scene.player
	var planar: Vector2 = scene.walk_feel.velocity(Vector2(dir.x, dir.z) * 80.0, 1.0 / 60.0)
	body.velocity.x = planar.x
	body.velocity.z = planar.y
	body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 320.0 * (1.0 / 60.0)
	var motion := Vector3(body.velocity.x, 0.0, body.velocity.z) * (1.0 / 60.0)
	if body.velocity.y <= 0.0 and preload("res://scripts/lol2/walk_step.gd").try_step(body, motion):
		body.velocity.x = 0.0
		body.velocity.z = 0.0
	body.move_and_slide()
