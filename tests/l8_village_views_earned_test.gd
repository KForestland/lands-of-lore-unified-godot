extends SceneTree
## BJ12 (owner 2026-11-10, r18 from the F2 darker start: "the point to click is not on ... cant get a silver leaf"). The Darker
## Jungle village chain as a VILLAGE-FIRST player, with the real E key and real mouse clicks on the panel buttons, on foot:
## the village before anything else (the guard says what he wants, a Journal note is written) -> Daniel at the entry (offer,
## hoppers, pick up) -> the temple scene -> the village: the guard, then the clearing with its three treehouses like the
## original scene's views (HINTBOOK 2984-3009) -> the shaman's sigil, the Journal note and the Atlas marker for the
## cemetery gate in the east -> the herbalist's jars -> on foot to the gate region -> native Dracoid Cemetery arrival ->
## E with the sigil opens the main gate. Creatures in the way are walked round, not fought (book: "Do not attack him").
const Save = preload("res://scripts/lol2/act2_save.gd")
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const Places = preload("res://scripts/lol2/atlas_places.gd")
const INPUT := "~/AI_COMMS/act1_completion_20261017/r12w_qualification/campaign/userdata/act1_dark_halls_darker_arrival.json"
const HASH := "065d4b814569c069490c0b4625177862918b2798ea504acf6ae89172b83baa92"
const SIGIL := "l8:shaman:Dracoid_sigil"
var failures := 0
var scene: Node
var journey: Node
func check(ok: bool, message: String) -> bool:
	if not ok: failures += 1; print("FAIL L8 village views: ", message)
	return ok
func _initialize(): run.call_deferred()
func key(code: int) -> void:
	var d := InputEventKey.new(); d.keycode = code; d.physical_keycode = code; d.pressed = true; Input.parse_input_event(d); Input.flush_buffered_events()
	await process_frame
	var u := InputEventKey.new(); u.keycode = code; u.physical_keycode = code; u.pressed = false; Input.parse_input_event(u); Input.flush_buffered_events()
	await process_frame
## A real left click on the panel button whose text contains `part` (the mouse event goes through the viewport's GUI).
func click(part: String) -> bool:
	for c in journey.box.get_children():
		if c is Button and not c.disabled and part in c.text:
			var at: Vector2 = (c as Button).get_global_rect().get_center()
			var move := InputEventMouseMotion.new(); move.position = at; move.global_position = at; root.push_input(move)
			await process_frame
			for pressed in [true, false]:
				var e := InputEventMouseButton.new(); e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.position = at; e.global_position = at
				root.push_input(e)
				await process_frame
			await process_frame
			return true
	return false
func texts() -> String:
	var out := ""
	for c in journey.box.get_children():
		if c is Label: out += c.text + " "
		elif c is Button: out += "[" + c.text + "] "
	return out
## Walks the waypoints on foot. Creatures near the line push the path aside (a player walks round a guard); a stall on
## plain ground hops (the stair lip). `until` ends the leg early when the journey's target becomes that id.
func walk(points: Array, label: String, until: String = "") -> bool:
	var pop = scene.get("act2_creatures")
	for index in points.size():
		var goal := Vector3(points[index][0], 0, points[index][1])
		var prior: Vector3 = scene.player.position
		var stalled := 0; var hops := 0; var reached := false
		for tick in 3000:
			if until != "" and journey != null and journey.target() == until: return true
			var d: Vector3 = goal - scene.player.position; d.y = 0
			if d.length() < 9.0 or (index < points.size() - 1 and d.length() < 40.0 and stalled > 5): reached = true; break
			var steer := d.normalized()
			if is_instance_valid(pop):
				# A group standing on the waypoint itself (the eight wild Hulines gather on one nav midpoint north of the
				# village): a player walks past the group, so the point counts as passed from just outside it.
				var crowded := false
				for id in pop.bodies:
					if pop.state.actors[id].present and Vector2(pop.bodies[id].global_position.x - goal.x, pop.bodies[id].global_position.z - goal.z).length() < 45.0: crowded = true; break
				if crowded and index < points.size() - 1 and d.length() < 110.0: reached = true; break
				for id in pop.bodies:
					if not pop.state.actors[id].present: continue
					var away: Vector3 = scene.player.global_position - pop.bodies[id].global_position; away.y = 0
					if away.length() < 70.0 and away.length() > 0.01:
						var side := Vector3(-d.z, 0, d.x).normalized()
						if side.dot(away) < 0: side = -side
						steer += (away.normalized() * 0.6 + side * 1.2) * (1.0 - away.length() / 70.0)
			if scene.player.position.distance_to(prior) < 0.05: stalled += 1
			else: stalled = 0
			prior = scene.player.position
			if stalled == 20 and scene.player.is_on_floor() and hops < 16: scene.request_jump(); hops += 1; stalled = 0
			if stalled > 200: break
			scene.move_grounded(steer.normalized(), 1.0 / 60.0); await physics_frame
		if not reached:
			var close := ""
			if is_instance_valid(pop):
				for id in pop.bodies:
					if pop.state.actors[id].present and pop.bodies[id].global_position.distance_to(scene.player.global_position) < 200.0: close += " %s@%s" % [id, str(pop.bodies[id].global_position.round())]
			return check(false, "%s: stopped at waypoint %d/%d at %s, goal %s, creatures near:%s (resets %s)" % [label, index, points.size(), str(scene.player.position.round()), str(goal), close, str(scene.get("resets"))])
	return true
func notes() -> Array: return MyJournal.notes(scene)
func run():
	Engine.time_scale = 4; Engine.physics_ticks_per_second = 240
	# Headless starts with a 64x64 root window; the panel's buttons lie outside it and a real click cannot land.
	root.size = Vector2i(1280, 720)
	if not check(FileAccess.get_sha256(INPUT) == HASH, "pinned earned Act 1 arrival (the F2 darker start's save)"): quit(1); return
	var source := Save.read_save(INPUT, "lol2-restoration-darker-jungle")
	if not check(source.error.is_empty(), "earned save validates: " + str(source.error)): quit(1); return
	source.state.inventory.health = 30 # The F2 darker start arrives at full health (entry "full_health", ledger 0553).
	set_meta("lol2_darker_resume", source.state); Engine.set_meta("lol2_enhanced", false)
	scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate(); scene.adapter_exit_seeds = false
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	if not check(scene.ready_for_review, "production scene ready"): quit(1); return
	scene.player.set_physics_process(false); scene.set_physics_process(false)
	scene.starting_magic.interface_request = true
	scene.progression.change_scene_enabled = false
	journey = scene.get_node("L8Journey")
	var hints: Node = scene.get_node("L8VillageHints")
	var legs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_bj12_village_routes.json")).legs
	# 1. The village first: no blade shown, no temple seen. The guard answers and the Journal says what he wants.
	if not await walk(legs.start_to_village, "the start to the village", "village"): quit(1); return
	for i in 20: await process_frame
	check(journey.target() == "village" and "village guard" in journey.hint.text, "the village answers a player who comes here first (hint '%s')" % journey.hint.text)
	await key(KEY_E)
	check(journey.opened == "village" and "Daniel" in texts() and not ("Show Daniel" in texts()), "the guard says what he wants: %s" % texts())
	await key(KEY_ESCAPE)
	hints.check()
	check("l8_guard_wants_blade_back" in notes(), "the Journal notes the blade the guard wants (%s)" % str(notes()))
	# 2. Daniel at the entry.
	if not await walk(legs.village_to_daniel, "the village to Daniel", "entry"): quit(1); return
	await key(KEY_E)
	check(journey.opened == "entry", "E opens the meeting with Daniel")
	for part in ["Offer grandfather", "Continue the meeting", "Pick up the dropped"]:
		check(await click(part), "a real click on '%s' (%s)" % [part, texts()])
	check(str(scene.quest_state.l8_journey.gift) == "recovered", "the blade is back in the pack after the hoppers")
	await key(KEY_ESCAPE)
	# 3. The temple scene plays on approach.
	if not await walk(legs.daniel_to_temple, "Daniel to the temple"): quit(1); return
	for i in 30: await process_frame
	check(bool(scene.quest_state.l8_journey.temple_visited), "the temple scene is seen")
	# 4. The village: the guard, then the clearing and its treehouses.
	if not await walk(legs.temple_to_village, "the temple to the village", "village"): quit(1); return
	await key(KEY_E)
	check(await click("Show Daniel's blade"), "the guard takes the blade's sight (%s)" % texts())
	check(bool(scene.quest_state.l8_journey.admitted) and "herbalist's treehouse" in texts() and "shaman's treehouse" in texts() and "Daniel's treehouse" in texts(), "admitted: the clearing shows the three treehouses (%s)" % texts())
	check(await click("Approach the shaman"), "approach the shaman's treehouse")
	check("Speak with the shaman" in texts() and "doorway to the right" in texts(), "the shaman's view: the shaman and the doorway to his right (%s)" % texts())
	check(await click("Speak with the shaman"), "speak with the shaman")
	check(SIGIL in scene.carried_collected and bool(scene.quest_state.l8_journey.key_awarded), "the shaman gives the cemetery sigil")
	check(await click("Step back"), "step back to the clearing")
	check("Dracoid Cemetery" in texts() and "east" in texts(), "the clearing now says where the sigil belongs (%s)" % texts())
	check(await click("Approach the herbalist"), "approach the herbalist's treehouse")
	var before: int = scene.carried_collected.size()
	check(await click("Take ironwood sap") and scene.carried_collected.size() == before + 1, "a jar's ironwood sap is taken (%s)" % texts())
	check(await click("Step back"), "step back again")
	await key(KEY_ESCAPE)
	check(journey.opened == "" and not paused, "Escape leaves the village scene")
	hints.check()
	check("l8_cemetery_gate_east" in notes(), "the Journal says the cemetery gate is east of the village (%s)" % str(notes()))
	var markers: Array = Places.active_plot("L8_SJ", notes(), scene.quest_state)
	check(markers.any(func(m): return str(m.note) == "l8_cemetery_gate_east" and str(m.place) == "cemetery_gate"), "the Atlas marks the cemetery gate (%s)" % str(markers.map(func(m): return m.note)))
	var path := "res://tmp/l8_village_views_earned_save.json"
	check(scene._quicksave_unrecorded(path).is_empty() and scene._quickload_unrecorded(path).is_empty(), "F5/F9 with the sigil")
	journey = scene.get_node("L8Journey")
	scene.player.set_physics_process(false); scene.set_physics_process(false); scene.starting_magic.interface_request = true
	scene.progression.change_scene_enabled = false
	check(SIGIL in scene.carried_collected and "l8_cemetery_gate_east" in notes(), "the sigil and the note survive the reload")
	# 5. On foot to the cemetery gate region; the native level change; the main gate takes the sigil on E.
	if not await walk(legs.village_to_cemetery_exit, "the village to the cemetery gate region"): quit(1); return
	for i in 20: await process_frame
	var changes: Array = scene.progression.level_changes
	if not check(changes.size() > 0 and int(changes.back().level) == 10 and int(changes.back().selector) == 1, "region 908 requests the Dracoid Cemetery, arrival 1 (%s)" % str(changes)): quit(1); return
	scene.progression.change_scene_enabled = true
	scene.progression._change_level(changes.back())
	await scene_changed
	scene = current_scene; journey = null
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	scene.player.set_physics_process(false); scene.set_physics_process(false); scene.starting_magic.interface_request = true
	scene.progression.change_scene_enabled = false
	check(scene.area_id == "L10_DC" and SIGIL in scene.carried_collected, "native cemetery arrival with the sigil (%s)" % str(scene.get("area_id")))
	var gate: Node = scene.get_node("L10MainGate")
	if not await walk(legs.cemetery_arrival_to_gate, "the cemetery arrival to the main gate"): quit(1); return
	scene.camera.look_at(gate.AIM, Vector3.UP)
	for i in 10: await process_frame
	check(gate.hint.text == "E — Unlock with the Dracoid Sigil", "the gate asks for the sigil (hint '%s' at %s)" % [gate.hint.text, str(scene.player.position.round())])
	await key(KEY_E)
	check(gate.opened(), "E with the sigil opens the cemetery's main gate")
	check(scene._quicksave_unrecorded("res://tmp/l8_village_views_cemetery_save.json").is_empty(), "cemetery save")
	scene.queue_free(); await process_frame
	if failures == 0: print("PASS L8 village-first player: guard's word -> Daniel -> temple -> village views (shaman's sigil, herbalist) -> Journal + Atlas point east -> on foot into the Dracoid Cemetery -> E opens the gate")
	quit(0 if failures == 0 else 1)
