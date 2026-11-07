extends "res://tests/player_continuity_restart_test.gd"
## Jungle -> Hive -> Jungle continuity, restart phase. A NEW process after player_continuity_hive_return_test: fresh Hive
## and Jungle scenes load the saves written there with real HUD Load clicks (sha256 checked) and must equal the
## save-time snapshots with no allowed change, differ from a fresh start, and agree with the HUD.
func run() -> void:
	var phase1 = JSON.parse_string(FileAccess.get_file_as_string(DIR + "hive_return_phase1.json"))
	if not check(phase1 is Dictionary and phase1.saves.has("hive_return_hive") and phase1.saves.has("hive_return_jungle"),"run player_continuity_hive_return_test first"): return
	var result := {}
	for entry in [["hive_return_hive","res://scenes/lol2/hive_review.tscn"],["hive_return_jungle","res://scenes/lol2/jungle_walkthrough.tscn"]]:
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
		var hud = area.interface_hud; var magic = area.starting_magic
		await cursor(hud, true)
		if not hud.sheet.visible or hud.atlas.visible: await click(hud.buttons[0])
		var fighting: Dictionary = magic.fighting_state()
		if not check(("Health: %d / 30" % magic.health()) in hud.sheet_body.text and ("Fighting: level %d (%d XP)" % [int(fighting.level), int(fighting.experience)]) in hud.sheet_body.text,"%s HUD disagrees after load: '%s'" % [entry[0], hud.sheet_body.text]): return
		await shot(entry[0] + "_restart")
		await finish(area)
	var file := FileAccess.open(DIR + "hive_return_phase2.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ", true)); file.close()
	print("PASS player_continuity_hive_restart: new process, Hive and Jungle saves from the Jungle->Hive->Jungle trip load by real Load clicks with zero difference from their save-time snapshots; HUD agrees. %s" % JSON.stringify(result))
	quit()
