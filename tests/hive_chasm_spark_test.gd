extends SceneTree
## Hive chasm (rock233, native kind9 mask 0x09FF): a player who drops onto the closed gorge floor is put back on the
## east bank; from there the production Spark ray (player_starting_magic.spark) aimed at the loose rock starts the
## collapse, as a melee strike does (hive_chasm_input_test).
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL hive_chasm_spark: ", message); quit(1); return false
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	for i in range(1500):
		await process_frame
		if scene.get("ready_for_review"): break
	if not scene.get("ready_for_review"): return fail("Hive not ready")
	scene.set_development_mode(false)
	var chasm = scene.get_node("Chasm")
	if chasm.gorge.size() != chasm.GORGE.size(): return fail("Gorge regions not loaded")
	# The owner's 2026-10-22 F10 spot: gorge floor region 94.
	scene.player.position = Vector3(-930.45,-567.95,-5875.70)
	scene.player.velocity = Vector3.ZERO
	var rescued := false
	for i in range(30):
		await physics_frame
		if scene.player.position.is_equal_approx(chasm.BANK): rescued = true; break
	if not rescued: return fail("Gorge floor did not return the player to the bank: %s" % scene.player.position)
	if chasm.activated: return fail("Rescue activated the chasm")
	scene.set_physics_process(false)
	chasm.set_physics_process(false)
	scene.player.position = chasm.BANK
	scene.camera.look_at(chasm.trigger.global_position+Vector3(0,36,0))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in range(2): await physics_frame
	scene.starting_magic.spark()
	if not chasm.activated or chasm.trigger.collision_layer != 0: return fail("Spark did not bring the rock down")
	chasm.advance(1)
	scene.starting_magic.spark()
	if chasm.elapsed != 1: return fail("A second Spark restarted the collapse")
	scene.queue_free()
	await process_frame
	print("PASS hive_chasm_spark: gorge floor returns the player to the east bank, production Spark at rock233 starts the collapse once")
	quit(0)
