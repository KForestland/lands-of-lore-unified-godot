extends SceneTree
## Ordinary-player route through the village / tavern / LIZ triggers with EVERY owner live. Nothing is disabled;
## movement is production move_grounded along source route fixtures; rooms use real viewport mouse clicks and the
## real Escape key through the engine input queue (private display only).
## SUPPLIED initial state (labelled; not certified here):
##   S1 the main village gate is open (its rescue/speech admission is covered by jungle_village_gate_test);
##   S2 Luther starts inside the gate at the village_to_followup start point (region 3811), human form, health 30.
## EARNED transitions (certified by this test when it passes):
##   E1 the follow-up arm and its speech, by walking (village_to_followup + approach);
##   E2 region 3501 entry by walking -> VILLAGE (TAVERN intro played naturally) and Left_Village 0->2 (g7092);
##   E3 click on VILLAGE hotspot 2 -> CAN first visit, natural playback; Escape -> farewell (flag34, relationship 0);
##   E4 click on hotspot 3 -> LIZ (LIZTRAN), click on hotspot 0 -> one beehive wax; Escape -> VILLAGE; Escape -> world.
## E5 (first observed as a probe, now asserted; the outcome is also recorded in user://tests/tavern_liz_ordinary_route.json):
##   P1 can Luther walk back out through the gate passage (region 3805) after the follow-up closes?
##      If so, Left_Village 2->3 (g7950) earned; then walking back in -> Bacatta57 sealing entry,
##      click hotspot 2 -> maid (alert), click hotspot 3 -> LIZ after the seal, and the alarm afterwards.
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
const BeeWax = preload("res://scripts/lol2/jungle_beehive_wax.gd")
const VillageState = preload("res://scripts/lol2/jungle_village_state.gd")
const Follow = preload("res://scripts/lol2/jungle_followup_state.gd")
const PASSAGE := Vector2(-1412,-5249)
const OUTSIDE := Vector2(-1300,-5240)
var scene
var rooms
var routes: Dictionary
var failed := false
var probe := {"supplied":["S1 main gate open (local24=1, pose 100)","S2 start at village_to_followup point 0 (region 3811)"]}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); write_probe(); quit(1)
	return ok
func write_probe() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	var f := FileAccess.open("user://tests/tavern_liz_ordinary_route.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(probe, " ", true) + "\n")
func bank() -> Dictionary: return rooms.state()
func click_hotspot(room: String, index_rect: Rect2) -> bool:
	for hit in rooms.hotspots:
		if hit.get_meta("room") == room and hit.visible and Rect2(hit.position, hit.size).is_equal_approx(index_rect):
			var at: Vector2 = hit.get_global_rect().get_center()
			for pressed in [true, false]:
				var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = at
				Input.parse_input_event(e); Input.flush_buffered_events()
			return true
	return false
func escape() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = KEY_ESCAPE; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
	await process_frame
func settle(limit: int = 20000) -> bool:
	for i in limit:
		if not Speech.active(bank().get("conversation", Speech.initial())): return true
		await physics_frame
	return false
func walk(points: Array, label: String, until: Callable = Callable(), record_block := false) -> bool:
	for i in points.size():
		var target := Vector2(points[i][0], points[i][1]); var reached := false
		for tick in range(2400):
			await physics_frame
			if until.is_valid() and until.call(): return true
			if scene.has_node("FollowupDialogue") and scene.followup_dialogue.active(): continue
			var offset := target - Vector2(scene.player.position.x, scene.player.position.z)
			if offset.length() < 3: reached = true; break
			var delta: float = scene.player.get_physics_process_delta_time()
			var direction := offset.normalized() * minf(1, offset.length() / (80 * delta))
			scene.move_grounded(Vector3(direction.x, 0, direction.y), delta)
			if scene.resets != 0 or scene.flying: return check(false, label + ": reset/flight")
		if not reached:
			if record_block:
				probe[label] = "blocked at waypoint %d target %s player %s" % [i, target, scene.player.position]
				return false
			return check(false, "%s blocked at waypoint %d target %s player %s" % [label, i, target, scene.player.position])
	return true
func run() -> void:
	Engine.time_scale = 4.0; Engine.physics_ticks_per_second = 240
	routes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_quest_walk_routes.json"))
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	for i in 6: await process_frame
	scene.set_process_unhandled_input(true)
	rooms = scene.monastery
	# S1, S2 (supplied).
	scene.village_gate.state().local24 = 1; scene.village_gate.state().elapsed = VillageState.DURATION; scene.village_gate.restore()
	var p0: Array = routes.village_to_followup.points[0]
	scene.player.position = Vector3(p0[0], 32, p0[1]); scene.player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 4: await physics_frame
	# E1: follow-up by walking.
	if not await walk(routes.village_to_followup.points, "village_to_followup"): return
	for i in range(600):
		await physics_frame
		scene.move_grounded(Vector3.FORWARD, scene.player.get_physics_process_delta_time())
		if scene.followup_dialogue.active(): break
	for i in range(40000):
		await physics_frame
		if not scene.followup_dialogue.active() and scene.followup_gate.pose == 0: break
	probe["E1_followup"] = {"local18": int(scene.followup_gate.state().local18), "speech": float(scene.followup_gate.state().speech), "pose": scene.followup_gate.pose}
	# E2: walk into region 3501 -> VILLAGE.
	if not await walk(routes.followup_to_tavern.points, "followup_to_tavern", func(): return rooms.active()): return
	if not check(rooms.active() and bank().room == "VILLAGE" and int(bank().locals.Left_Village) == 2, "E2 village entry: room '%s' Left_Village %s" % [bank().room, bank().locals.Left_Village]): return
	if not check(await settle(), "TAVERN intro did not finish"): return
	probe["E2"] = "VILLAGE by walking; Left_Village 0->2; intro flag41=%d" % int(bank().flags["41"])
	# E3: CAN by click, farewell by Escape.
	await process_frame
	if not check(click_hotspot("VILLAGE", Rect2(244,220,142,90)) and bank().room == "CAN", "E3 CAN click: room '%s'" % bank().room): return
	if not check(await settle(), "CAN conversation did not finish"): return
	await escape()
	if not check(await settle() and bank().room == "VILLAGE" and bank().flags["34"] == 1 and int(bank().globals.GV_BACATTA_RELATIONSHIP) == 0, "E3 farewell: room '%s' flag34 %s" % [bank().room, bank().flags.get("34")]): return
	probe["E3"] = "CAN first visit by click; farewell by Escape (flag34, relationship 0)"
	# E4: LIZ by click, wax by click.
	var before: int = scene.carried_collected.filter(func(i): return BeeWax.valid(i)).size()
	if not check(click_hotspot("VILLAGE", Rect2(425,211,151,99)) and bank().room == "LIZ", "E4 LIZ click: room '%s'" % bank().room): return
	if not check(await settle(), "LIZTRAN did not finish"): return
	if not check(await settle(), "LIZ entry cue did not finish"): return
	if not check(click_hotspot("LIZ", Rect2(91,282,55,57)) and bank().flags["162"] == 1 and scene.carried_collected.filter(func(i): return BeeWax.valid(i)).size() == before + 1, "E4 wax click"): return
	await settle()
	await escape(); await escape()
	if not check(not rooms.active() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "E4 back to the world: room '%s'" % bank().room): return
	probe["E4"] = "LIZ by click (LIZTRAN), wax by click (flag162), Escape x2 to the world"
	# P1 probe: walk back out through the gate passage.
	var back: Array = routes.followup_to_tavern.points.duplicate(); back.reverse()
	var out_route: Array = routes.village_to_followup.points.duplicate(); out_route.reverse()
	var out_ok: bool = await walk(back, "P1_tavern_to_followup", Callable(), true)
	if out_ok: out_ok = await walk(out_route, "P1_followup_to_gate", Callable(), true)
	if out_ok: out_ok = await walk([[PASSAGE.x, PASSAGE.y], [OUTSIDE.x, OUTSIDE.y]], "P1_passage", Callable(), true)
	probe["P1_walked_out"] = out_ok
	probe["P1_left_village"] = int(bank().locals.Left_Village)
	probe["P1_followup_pose"] = scene.followup_gate.pose
	if out_ok and int(bank().locals.Left_Village) == 3:
		# Return: sealing entry, maid, LIZ after the seal.
		var in_route: Array = routes.village_to_followup.points
		var back_in: bool = await walk([[PASSAGE.x, PASSAGE.y]] + in_route, "P1_return_gate", Callable(), true)
		if back_in: back_in = await walk(routes.followup_to_tavern.points, "P1_return_tavern", func(): return rooms.active(), true)
		probe["P1_returned"] = back_in and rooms.active()
		if back_in and rooms.active():
			probe["P1_sealed"] = scene.bacatta57.sealed()
			await settle()
			click_hotspot("VILLAGE", Rect2(244,220,142,90))
			probe["P1_maid_started"] = bank().conversation.sequence == "CAN_MAID"
			await settle()
			probe["P1_alert"] = int(scene.village_gate.state().shared29)
			probe["P1_flag267"] = int(bank().flags["267"])
			probe["P1_can_refused_after"] = not click_hotspot("VILLAGE", Rect2(244,220,142,90)) or bank().room == "VILLAGE"
			probe["P1_liz_after_seal"] = click_hotspot("VILLAGE", Rect2(425,211,151,99)) and bank().room == "LIZ"
			await settle(); await escape(); await escape()
			var fired := false
			for i in 2400:
				await physics_frame
				if scene.village_alarm.movable_target(78) == 0: fired = true; break
			probe["P1_alarm_fired_after_return"] = fired
	write_probe()
	# Now asserted (first observed as a probe on 2026-10-10): the full ordinary chain is reachable.
	for key in ["P1_walked_out","P1_returned","P1_sealed","P1_maid_started","P1_can_refused_after","P1_liz_after_seal","P1_alarm_fired_after_return"]:
		if not check(probe.get(key, false) == true, "Ordinary chain step %s: %s" % [key, probe.get(key)]): return
	if not check(probe.P1_left_village == 3 and probe.P1_alert == 1 and probe.P1_flag267 == 1, "Ordinary chain values: %s" % [probe]): return
	Engine.time_scale = 1.0; Engine.physics_ticks_per_second = 60
	print("PASS tavern_liz_ordinary_route (earned E1-E4; supplied S1/S2): probe ", JSON.stringify(probe))
	quit()
