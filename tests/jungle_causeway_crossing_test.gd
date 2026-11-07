extends SceneTree
## Rendered check (owner r12e report 5): before an exit ending the causeway carries an ordinary grounded walk from the
## west bank (4250,-3700) to the east bank (5500,-3700) at -114; after an ending (g17352) the same walk back west drops
## into the river at -200 where the causeway stood. Uses the shared move_grounded (gravity, step, move_and_slide).
const FLAGS := {"shared": {"13": 0, "14": 1, "18": 1, "47": 0}, "locals": {"41": 0, "49": 0, "51": 0}}
const FOOT := 32.0
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_causeway_crossing: ", message); quit(1)

func walk(from: Vector3, direction: Vector3, until_x: float, frames: int) -> float:
	scene.player.global_position = from
	scene.player.velocity = Vector3.ZERO
	var lowest := INF
	for i in 30:
		await physics_frame
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
	for i in frames:
		await physics_frame
		scene.move_grounded(direction, 1.0 / 60.0)
		lowest = minf(lowest, scene.player.global_position.y - FOOT)
		if (direction.x > 0 and scene.player.global_position.x >= until_x) or (direction.x < 0 and scene.player.global_position.x <= until_x): break
	return lowest

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	scene.set_physics_process(false)
	scene.exit_encounter.set_physics_process(false)
	var lowest: float = await walk(Vector3(4250, -114 + FOOT, -3700), Vector3(1, 0, 0), 5500.0, 1800)
	if scene.player.global_position.x < 5500.0 or lowest < -120.0: return fail("Standing causeway walk stopped at %s (lowest foot %.1f)" % [scene.player.global_position, lowest])
	var ctrl = scene.exit_encounter
	ctrl.encounter.locals["48"] = 3
	ctrl.request_prop4398_event20(FLAGS.duplicate(true))
	ctrl.skip_line()
	if not scene.causeway.collapsed(): return fail("Ending did not collapse the causeway")
	lowest = await walk(Vector3(5000, -114 + FOOT, -3700), Vector3(-1, 0, 0), 4500.0, 1800)
	if lowest > -190.0: return fail("Walk over the collapsed causeway stayed at %.1f" % lowest)
	print("PASS jungle_causeway_crossing: grounded walk crosses the standing causeway at -114; after the ending the same line drops to %.1f" % lowest)
	quit(0)
