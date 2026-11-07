extends "res://tests/player_continuity_restart_test.gd"
## Jungle -> village rooms -> Jungle continuity, restart phase. A NEW process after player_continuity_room_test: a fresh
## Jungle scene loads the save written there with real HUD Load clicks (sha256 checked) and must equal the
## save-time snapshots with no allowed change, differ from a fresh start, and agree with the HUD. A load at the tavern
## doorway re-enters VILLAGE (recorded as reentered_room); the test leaves it by Escape with the player state unchanged.
func run() -> void:
	var phase1 = JSON.parse_string(FileAccess.get_file_as_string(DIR + "room_phase1.json"))
	if not check(phase1 is Dictionary and phase1.saves.has("room_jungle"),"run player_continuity_room_test first"): return
	var result := {}
	for entry in [["room_jungle","res://scenes/lol2/jungle_walkthrough.tscn"]]:
		var saved: Dictionary = phase1.saves[entry[0]]
		var bytes := FileAccess.get_file_as_bytes(saved.path)
		var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256); ctx.update(bytes)
		if not check(ctx.finish().hex_encode() == saved.sha256,"%s save changed since the travel phase" % entry[0]): return
		var area = await open_fresh(entry[1])
		var fresh := Continuity.from_host(area)
		if not await load_click(area, saved.path): return
		var loaded := Continuity.from_host(area)
		var errors := Continuity.compare(Continuity._normalized(saved.snapshot), loaded)
		result[entry[0]] = {"errors": errors, "fields": loaded.size(), "fresh_differs": not Continuity.compare(fresh, loaded).is_empty()}
		if not check(errors.is_empty(),"%s after restart+load: %s" % [entry[0], errors]): return
		if not check(result[entry[0]].fresh_differs,"%s: save carried nothing beyond a fresh start" % entry[0]): return
		# Observed 2026-10-12: a save made at the tavern doorway (inside entry region 3501) re-enters VILLAGE on load.
		# Leave it with ordinary Escape presses; the player state must be unchanged by that.
		result[entry[0]].reentered_room = str(area.monastery.state().get("room", ""))
		if area.monastery.active():
			for i in 4000:
				await physics_frame
				if not preload("res://scripts/lol2/monastery_conversation.gd").active(area.monastery.state().get("conversation", {"sequence":"","cursor":0})): break
			for k in 2:
				for pressed in [true, false]:
					var e := InputEventKey.new(); e.keycode = KEY_ESCAPE; e.pressed = pressed
					Input.parse_input_event(e); Input.flush_buffered_events()
				for i in 4: await process_frame
			var after_exit := Continuity.compare(loaded, Continuity.from_host(area))
			if not check(not area.monastery.active() and after_exit.is_empty(),"%s leaving the re-entered room: active %s diff %s" % [entry[0], area.monastery.active(), after_exit]): return
		var hud = area.interface_hud; var magic = area.starting_magic
		await cursor(hud, true)
		if not hud.sheet.visible or hud.atlas.visible: await click(hud.buttons[0])
		if not check(hud.sheet.visible and not hud.atlas.visible,"%s Character page did not open" % entry[0]): return
		var fighting: Dictionary = magic.fighting_state()
		if not check(("Health: %d / 30" % magic.health()) in hud.sheet_body.text and ("Fighting: level %d (%d XP)" % [int(fighting.level), int(fighting.experience)]) in hud.sheet_body.text,"%s HUD disagrees after load: '%s'" % [entry[0], hud.sheet_body.text]): return
		await shot(entry[0] + "_restart")
		await finish(area)
	var file := FileAccess.open(DIR + "room_phase2.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ", true)); file.close()
	print("PASS player_continuity_room_restart: new process, the Jungle save made after the village rooms (wax carried) loads by real Load clicks with zero difference from their save-time snapshots; HUD agrees. %s" % JSON.stringify(result))
	quit()
