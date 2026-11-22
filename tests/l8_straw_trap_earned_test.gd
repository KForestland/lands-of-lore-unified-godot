extends SceneTree
## Owner r18 F10 15-45-37 at (4405, 972). The straw pit should start hidden. A walk onto it,
## with no jump, drops the body into region 3255. The source stairs then stand so the pit
## is not a softlock. Opcode 18 and kind-6 caller 7 stay unentered.
const Trap = preload("res://scripts/lol2/l8_straw_trap.gd")
const REPORT := Vector3(4405, 32, 973)
const CENTRE := Vector3(4277, 32, 911)
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func approach(scene: Node, goal: Vector3, stop_at: float, stop_low: bool = false) -> void:
	var stuck: int = 0
	var previous: Vector3 = scene.player.position
	for _tick in 900:
		if stop_low and scene.player.position.y < -20.0:
			break
		var delta: Vector3 = goal - scene.player.position
		delta.y = 0.0
		if delta.length() < stop_at:
			break
		scene.move_grounded(delta.normalized(), 1.0 / 60.0)
		await physics_frame
		var step: float = Vector2(scene.player.position.x - previous.x, scene.player.position.z - previous.z).length()
		previous = scene.player.position
		if step < 0.05:
			stuck += 1
		else:
			stuck = 0
		if stuck >= 25:
			break

func boot() -> Node:
	var scene: Node = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	for _i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	return scene

func run() -> void:
	check(not Trap.OP9_ENTERED and not Trap.OP18_ENTERED and not Trap.CALLER7_KNOWN, "opcode 9, opcode 18, and caller 7 stay unentered")
	check(Trap.validate(Trap.initial(), {}).is_empty(), "initial trap state")
	var scene: Node = await boot()
	if not scene.ready_for_review or scene.get_node_or_null("L8StrawTrap") == null:
		check(false, "darker jungle ready")
		await stop(scene, 1)
		return
	var trap: Node = scene.get_node("L8StrawTrap")
	var assemblies: Node = scene.preview_assemblies
	scene.player_form = 0
	scene.flying = false
	scene.set_physics_process(false)
	scene.player.position = REPORT
	scene.player.velocity = Vector3.ZERO
	for _i in 20:
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame
	check(scene.player.position.y > 24.0, "the report pose stays on the grass at %s" % scene.player.position)
	check(not trap.covers(scene.player.position.x, scene.player.position.z), "the report pose is outside the pit")
	check(trap.covers(CENTRE.x, CENTRE.z), "the straw centre is the pit")
	check(not assemblies.is_present(93) and not assemblies.is_present(94), "ramps 93 and 94 start absent")
	check(assemblies.solid_bodies[93].collision_layer == 0 and assemblies.solid_bodies[94].collision_layer == 0, "absent ramps do not collide")
	check(trap.get_node_or_null("StrawLid") != null, "the straw lid is up")
	check(trap.stake_scale() < 0.01, "ramp stakes start hidden, scale %s" % trap.stake_scale())
	check(not scene.quest_state.has("l8_straw_trap"), "the pit starts armed")
	await approach(scene, CENTRE, 4.0, true)
	for _i in 240:
		if scene.player.is_on_floor() and scene.player.position.y < -30.0:
			break
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame
	var sprung: bool = scene.quest_state.has("l8_straw_trap") and bool(scene.quest_state.l8_straw_trap.sprung)
	check(sprung and scene.player.position.y < -30.0 and scene.player.is_on_floor(), "a walk with no jump lands in the pit at %s" % scene.player.position)
	check(assemblies.is_present(93) and assemblies.is_present(94), "the stairs are present after the step")
	check(assemblies.solid_bodies[93].collision_layer == 0 and assemblies.solid_bodies[94].collision_layer == 0, "the source boxes stay off the plate")
	check(trap.get_node_or_null("StrawExit") != null, "the exit slope is up")
	check(trap.stake_scale() > 0.9, "ramp stakes show after the step, scale %s" % trap.stake_scale())
	var path := "res://tmp/l8_straw_trap_earned_save.json"
	var error: String = scene._quicksave_unrecorded(path)
	check(error.is_empty(), "pit save: " + error)
	var fallen_at: Vector3 = scene.player.position
	scene.free()
	var again: Node = await boot()
	if not again.ready_for_review:
		check(false, "reload ready")
		await stop(again, 1)
		return
	error = again._quickload_unrecorded(path)
	var again_trap: Node = again.get_node("L8StrawTrap")
	var again_assemblies: Node = again.preview_assemblies
	check(error.is_empty() and bool(again.quest_state.l8_straw_trap.sprung) and again_assemblies.is_present(93) and again_assemblies.is_present(94), "the sprung pit survives the save")
	check(again.player.position.distance_to(fallen_at) < 2.0, "the reload stands where the fall ended, at %s" % again.player.position)
	again.player_form = 0
	again.flying = false
	again.set_physics_process(false)
	await approach(again, Vector3(4290, -33, 950), 16.0)
	await approach(again, Vector3(4290, 32, 790), 18.0)
	for _i in 30:
		again.move_grounded(Vector3.ZERO, 1.0 / 60.0)
		await physics_frame
	check(again.player.position.y > 20.0 and not again_trap.covers(again.player.position.x, again.player.position.z), "walked back out of the pit to %s" % again.player.position)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures == 0:
		print("PASS earned L8 straw trap: the ramps started hidden, a walk with no jump dropped into the pit, and the stairs led back to the grass")
	await stop(again, 1 if failures else 0)
