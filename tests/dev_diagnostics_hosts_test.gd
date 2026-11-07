extends "res://tests/player_continuity_restart_test.gd"
## Development diagnostics, rendered acceptance on the four real hosts (docs/dev-diagnostics.md). Run with
## --demo-interface. Optional LOL2_EARNED_SAVES: the Jungle loads the R13 earned Jungle save (non-default player state)
## by HUD Load click; the other hosts use their fresh state.
## Per host (Cave, Museum, Jungle, Hive):
## - Cave while loading (before walkthrough_ready): capture() reports "loading" and reads no player state (the other
##   hosts have no observable loading phase here, so their "loading" branch is NOT exercised);
## - an early save refusal that shows no message is recorded (Cave: "still loading"; others: save while paused);
## - real F7 opens the panel; its text equals the report; the player fields equal the existing continuity projection
##   (Hive: compared after the capture, through Continuity.from_host);
## - capture leaves canonical state unchanged (the host's own save packer): synchronously with the tree paused, and
##   across the open panel's real Refresh click, screenshot and Copy click (both snapshots while paused);
## - the Copy report button puts exactly that text on the clipboard; opening did not;
## - F7 closes the panel and restores the previous pause and mouse state;
## - one screenshot per host with the panel open.
## r2 additions: with the opt-in off, F7 does nothing; each wrapper returns exactly what the unrecorded function returns
## in the same state (save and load); Hive at zero health shows "Vitals: health 0, dead" after a real Refresh click on
## an already-paused tree, which stays paused after F7 (prior pause true), while the travel projection still omits
## health; Jungle: the panel opens and closes over an open monastery room (supplied entry to MENT), leaving the room
## open and its mouse mode unchanged.
## Supplied: the opt-in flag is set on the overlay (equivalent to --dev-diagnostics); the Museum introduction is skipped.
const Diagnostics = preload("res://scripts/lol2/dev_diagnostics.gd")
const HOSTS := [["Cave", "res://scenes/lol2/cave_walkthrough.tscn"], ["Museum", "res://scenes/lol2/museum_walkthrough.tscn"],
	["Jungle", "res://scenes/lol2/jungle_walkthrough.tscn"], ["Hive", "res://scenes/lol2/hive_review.tscn"]]
const SAVE := "act1_broken_museum_jungle.json"
func canonical(area, kind: String) -> String:
	match kind:
		"Cave": return JSON.stringify(area._save_state(), "", true)
		"Museum": return JSON.stringify(area.checkpoint_state(), "", true)
		"Jungle": return JSON.stringify({"inventory": area.inventory_state(), "quests": area.quest_state}, "", true)
		"Hive": return JSON.stringify(area.area_handoff(), "", true)
	return ""
func f7() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = KEY_F7; e.physical_keycode = KEY_F7; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
	for i in 3: await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var overlay = root.get_node_or_null("PlaytestLocation")
	if not check(overlay != null, "PlaytestLocation autoload missing"): return
	# Opt-in off: F7 does nothing.
	overlay.diagnostics_enabled = false
	var mouse_before := Input.mouse_mode
	await f7()
	if not check(not overlay.panel_open() and not paused and Input.mouse_mode == mouse_before, "F7 acted without the opt-in"): return
	overlay.diagnostics_enabled = true
	var result := {}
	for entry in HOSTS:
		var kind: String = entry[0]
		var area = load(entry[1]).instantiate()
		if kind == "Museum": area.introduction_state = "complete"
		root.add_child(area); current_scene = area
		# Loading: Cave before walkthrough_ready (and its silent early save refusal).
		var loading := Diagnostics.capture(area)
		if kind == "Cave":
			if not check(loading.status == "loading" and loading.player.is_empty(), "Cave while loading: %s" % [loading]): return
			if not check(area._quicksave_unrecorded() == area.quicksave() and area._quickload_unrecorded() == area.quickload(), "Cave wrapper changed a return value"): return
			if not check(area.quicksave() == "The cavern is still loading." and Diagnostics.last_operation.reason == "The cavern is still loading." and Diagnostics.last_operation.area == "Cave", "Cave loading refusal not recorded: %s" % [Diagnostics.last_operation]): return
		for i in 900:
			await process_frame
			if area.get("walkthrough_ready") == null or area.walkthrough_ready: break
		for i in 6: await process_frame
		if kind == "Museum" and is_instance_valid(area.get("introduction")): area.introduction.close()
		if kind == "Jungle" and not OS.get_environment("LOL2_EARNED_SAVES").is_empty():
			var copy := DIR + "diagnostics_" + SAVE
			var out := FileAccess.open(copy, FileAccess.WRITE); out.store_buffer(FileAccess.get_file_as_bytes(OS.get_environment("LOL2_EARNED_SAVES").path_join(SAVE))); out.close()
			if not await load_click(area, copy): return
		for i in 4: await physics_frame
		if kind != "Cave":
			paused = true
			var pairs := [[area.quickload(), area._quickload_unrecorded()], [area.quicksave(), area._quicksave_unrecorded()]]
			var refusal: String = area.quicksave()
			paused = false
			if not check(pairs[0][0] == pairs[0][1] and pairs[1][0] == pairs[1][1] and not pairs[0][0].is_empty(), "%s wrapper changed a return value: %s" % [kind, pairs]): return
			if not check(refusal == "Close the current overlay before saving." and Diagnostics.last_operation.reason == refusal and Diagnostics.last_operation.area == kind, "%s paused refusal not recorded: %s" % [kind, Diagnostics.last_operation]): return
		var last: Dictionary = Diagnostics.last_operation.duplicate()
		# Capture alone, synchronously, with the tree paused: canonical state must be byte-identical.
		paused = true
		var sync_before := canonical(area, kind)
		Diagnostics.capture(area)
		var sync_equal := canonical(area, kind) == sync_before
		paused = false
		if not check(sync_equal, "%s capture() changed canonical state" % kind): return
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		DisplayServer.clipboard_set("sentinel")
		await f7()
		if not check(overlay.panel_open() and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "%s F7 did not open the panel" % kind): return
		if not check(DisplayServer.clipboard_get() == "sentinel", "%s opening wrote the clipboard" % kind): return
		var report: Dictionary = overlay.report
		if not check(report.status == "ready" and report.area == kind and overlay.report_label.text == Diagnostics.format(report), "%s report: %s" % [kind, report]): return
		if not check(not report.location.is_empty() and report.last_operation.reason == last.reason, "%s location/last operation" % kind): return
		# World clocks advance whenever the tree runs (probe 2026-10-12: Cave eyes/scenic_guard, Jungle regen_elapsed, Hive
		# curse/nest/ambush moved 0.05 s = 3 frames between unpaused snapshots), so the panel check compares two snapshots
		# taken while the panel holds the tree paused, around a real Refresh click, the screenshot and the Copy click.
		var before := canonical(area, kind)
		await click(overlay.refresh_button)
		if not check(overlay.report_label.text == Diagnostics.format(overlay.report), "%s refreshed text differs" % kind): return
		report = overlay.report
		var projection := Continuity.from_host(area)
		if not check(Continuity.compare(projection, report.player).is_empty() and Continuity.compare(report.player, projection).is_empty(), "%s player fields differ: %s" % [kind, Continuity.compare(projection, report.player)]): return
		await shot("diagnostics_" + kind.to_lower())
		await click(overlay.copy_button)
		if not check(DisplayServer.clipboard_get() == overlay.report_text and overlay.report_text.begins_with("LoL2 diagnostics | " + kind), "%s copied text differs" % kind): return
		if not check(paused and canonical(area, kind) == before, "%s panel capture/refresh/copy changed canonical state" % kind): return
		await f7()
		if not check(not overlay.panel_open() and not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "%s close did not restore pause/mouse" % kind): return
		if kind == "Hive":
			# Zero health: the travel packet omits it, the vitals line shows it. Prior pause true is kept.
			var warriors = area.get_node("Warriors")
			var kept_health: int = warriors.health
			paused = true
			await f7()
			warriors.health = 0
			await click(overlay.refresh_button)
			var dead: Dictionary = overlay.report
			var shown_dead: bool = "Vitals: health 0, dead (Warriors.health)" in overlay.report_label.text
			warriors.health = kept_health
			await f7()
			if not check(paused and not overlay.panel_open(), "Hive prior pause true not restored"): return
			paused = false
			if not check(dead.vitals.health == 0 and dead.vitals.status == "dead" and shown_dead and not dead.player.has("health"), "Hive zero health: %s" % [dead.vitals]): return
		if kind == "Jungle":
			# Over an open room (supplied entry): the room keeps its mouse mode and stays open.
			if not check(area.monastery.enter_room("MENT") and area.monastery.active(), "could not open MENT"): return
			for i in 3: await process_frame
			var room_mouse := Input.mouse_mode
			await f7()
			var room_report: Dictionary = overlay.report
			await f7()
			if not check(area.monastery.active() and Input.mouse_mode == room_mouse and not paused and room_report.status == "ready", "panel over MENT: active %s mouse %s" % [area.monastery.active(), Input.mouse_mode]): return
			area.monastery.leave_room()
		result[kind] = {"fields": report.player.size(), "quests": report.quests.size(), "last": report.last_operation.reason}
		area.queue_free()
		for i in 4: await process_frame
	print("PASS dev_diagnostics_hosts: Cave/Museum/Jungle/Hive — loading reported, silent early refusals recorded, F7 panel report equals the continuity projection, capture leaves canonical state unchanged, Copy report exact, F7 restores pause/mouse; opt-in off inert; wrappers return unchanged values; Hive zero health shown dead; panel over an open room; screenshots taken. %s" % JSON.stringify(result))
	quit()
