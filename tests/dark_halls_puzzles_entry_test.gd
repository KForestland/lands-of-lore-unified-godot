extends "res://tests/dark_halls_window_jump_test.gd"
## Every objective begins with the pinned repaired-monastery save and actual cellar entry.
## Route plans are source neighbors; there is no goal placement, actor edit, or disabled host.
var escape_driver: RefCounted

func run() -> void:
	var objective := OS.get_environment("LOL2_DH_PUZZLE")
	if objective.is_empty(): return fail("LOL2_DH_PUZZLE required")
	phase = "entry_" + objective
	if not await enter_from_monastery(): return
	var plans: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dark_halls_puzzles_walk.json"))
	if not plans.has(objective): return fail("unknown puzzle " + objective)
	if not await walk_points(plans[objective].points, objective): return
	if not scene.player.is_on_floor() or not scene.creatures.is_physics_processing() or not scene.is_physics_processing(): return fail("objective was not earned with live hosts")
	await capture("approach")
	var okay := false
	if objective == "atrium": okay = await pull_chain()
	elif objective == "iron": okay = await iron_door()
	elif objective == "escape": okay = await escape_window()
	elif objective == "bash": okay = await chop_door()
	elif objective == "orb":
		for i in 5: await physics_frame
		okay = bool(scene.orb.entered) and absf(scene.orb.orb_node.position.y - 900.0) < 1.0
		if not okay: return fail("earned region1596 entry did not raise orb")
		# Subsequent kind6/timer emitters remain unknown: the decoder probe covers them, not this walk.
	if not okay: return
	receipt.passed = true
	write_receipt()
	print("PASS dark_halls_puzzles_entry: ", objective, "; pinned monastery -> cellar -> entry1, live enemies, player input")
	quit(0)

func saved_roundtrip(check: Callable) -> bool:
	await f5()
	var saved_position: Vector3 = scene.player.position
	var earlier: String = scene.quickload(OUT + "enter_arrival_quicksave.json")
	if not earlier.is_empty() or bool(check.call()): return fail("earlier earned save kept puzzle state")
	await ensure_captured()
	await tap(KEY_F9)
	for i in 3: await physics_frame
	if not bool(check.call()) or scene.player.position.distance_to(saved_position) > 2: return fail("F9 lost puzzle or position")
	return true

func pull_chain() -> bool:
	look_toward(scene.atrium.chain)
	await physics_frame
	await tap(KEY_E)
	if not scene.atrium.is_open(): return fail("earned E did not pull chain")
	await capture("sunlight")
	return await saved_roundtrip(func(): return scene.atrium.is_open())

func iron_door() -> bool:
	look_toward(scene.crates.center_of(448))
	await physics_frame
	await tap(KEY_E)
	if scene.crates.state_of(448) != 1: return fail("earned E did not expose crystal448")
	# Walking into the crate drives it toward the Iron Door until the door stops it.
	if not await walk_to(Vector2(-1243,-615), 8, 60*30, "iron_shove", true, true): return false
	if scene.crates.center_of(448).z > -560: return fail("crate448 was not shoved toward door")
	if not scene.crates.door_blocking(): return fail("door opened before Spark")
	if not await walk_to(Vector2(-1243,-430), 8, 60*30, "iron_retreat"): return false
	if not await spark_crate(448): return false
	if scene.crates.door_blocking(): return fail("Spark did not remove Iron Door")
	if not await walk_to(Vector2(-1243,-650), 10, 60*40, "through_iron"): return false
	await capture("through_iron")
	return await saved_roundtrip(func(): return scene.crates.state_of(448) == 2 and not scene.crates.door_blocking())

func chop_door() -> bool:
	var doors: Node = scene.doors
	if doors.is_open("56"): return fail("approach used E on objective door56")
	for i in 3:
		look_toward(doors.leaves["56"].hinge.get_node("Leaf").global_position)
		await physics_frame
		await click_at(Vector2(640,360))
	for i in 90: await physics_frame
	if not doors.is_open("56"): return fail("earned clicks did not bash door56")
	await capture("bashed")
	return await saved_roundtrip(func(): return scene.doors.is_open("56"))

# Do not use E on the objective bashing leaf merely because the approach sees it.
func open_route_leaf(target: Vector2) -> void:
	var objective := OS.get_environment("LOL2_DH_PUZZLE")
	if objective == "bash" and scene.camera.global_position.distance_to(Vector3(-2612,125,-2459)) < 130: return
	await super.open_route_leaf(target)

func spark_crate(id: int) -> bool:
	await select_spell(KEY_1, "spark")
	look_toward(scene.crates.center_of(id))
	await physics_frame
	var before := health()
	# Ctrl+Q requests the level-three version through the real input handler.
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_Q
		event.physical_keycode = KEY_Q
		event.ctrl_pressed = true
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	for i in 5: await physics_frame
	if scene.crates.state_of(id) != 2: return fail("input Spark3 did not detonate crystal%d" % id)
	receipt.notes.append("crate%d blast player health %d -> %d; actors %s" % [id,before,health(),scene.crates.last_actor_damage])
	if health() <= 0: return fail("player fell to crate blast")
	return true

func escape_window() -> bool:
	if escape_driver == null: return fail("Use dark_halls_escape_entry_test for the escape input driver")
	return await escape_driver.run(self)
