extends "res://tests/player_continuity_chain_test.gd"
## Cave -> Museum -> Jungle continuity, restart phase (docs/player-continuity.md). A NEW process after
## player_continuity_chain_test: each area scene starts fresh, the HUD Load button (real click) loads the save written
## in the travel phase, and the live state must equal the snapshot taken when that save was made — no allowed changes.
## The HUD Character page and rings must agree after each load.
## Compatibility (optional): with LOL2_EARNED_SAVES=<dir> holding the R13 campaign saves act1_magic_museum_arrival.json
## and act1_broken_museum_jungle.json (earned by the R13 chain driver; read-only copies), each loads through the HUD
## and the live state equals the semantic content of the file.
## Supplied: the Museum introduction is skipped on the fresh Museum scene.

func open_fresh(path: String) -> Node:
	var area = load(path).instantiate()
	root.add_child(area); current_scene = area
	for i in 900:
		await process_frame
		if area.get("walkthrough_ready") == null or area.walkthrough_ready: break
	for i in 4: await process_frame
	if area.get("introduction_state") != null:
		area.introduction_state = "complete"
		if is_instance_valid(area.get("introduction")): area.introduction.close()
	for i in 2: await process_frame
	return area
func load_click(area, path: String) -> bool:
	var hud = area.interface_hud
	hud.save_path = path
	await cursor(hud, true)
	if not hud.sheet.visible or hud.atlas.visible: await click(hud.buttons[0])
	await click(hud.load_button)
	var ok: bool = not "failed" in hud.save_status.text and "loaded" in hud.save_status.text
	hud.close_sheet()
	await cursor(hud, false)
	return check(ok,"%s load click: '%s'" % [path, hud.save_status.text])
func finish(area) -> void:
	area.queue_free()
	for i in 3: await process_frame

func run() -> void:
	var phase1 = JSON.parse_string(FileAccess.get_file_as_string(DIR + "phase1.json"))
	if not check(phase1 is Dictionary and phase1.saves.size() == 3,"travel-phase receipt missing; run player_continuity_chain_test first"): return
	var result := {"restart": {}, "compatibility": {}}
	for entry in [["cave","res://scenes/lol2/cave_walkthrough.tscn","Cave"],["museum","res://scenes/lol2/museum_walkthrough.tscn","Museum"],["jungle","res://scenes/lol2/jungle_walkthrough.tscn","Jungle"]]:
		var saved: Dictionary = phase1.saves[entry[0]]
		var bytes := FileAccess.get_file_as_bytes(saved.path)
		var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256); ctx.update(bytes)
		if not check(ctx.finish().hex_encode() == saved.sha256,"%s save changed since the travel phase" % entry[0]): return
		var area = await open_fresh(entry[1])
		var fresh := Continuity.from_host(area)
		if not await load_click(area, saved.path): return
		var loaded := Continuity.from_host(area)
		var errors := Continuity.compare(Continuity._normalized(saved.snapshot), loaded)
		result.restart[entry[0]] = {"errors": errors, "fresh_differs": not Continuity.compare(fresh, loaded).is_empty()}
		if not check(errors.is_empty(),"%s after restart+load: %s" % [entry[0], errors]): return
		if not check(result.restart[entry[0]].fresh_differs,"%s: the save carried nothing beyond a fresh start" % entry[0]): return
		if not await hud_agrees(area, entry[2] + "_restart"): return
		await finish(area)
	var earned := OS.get_environment("LOL2_EARNED_SAVES")
	if not earned.is_empty():
		for entry in [["act1_magic_museum_arrival.json","res://scenes/lol2/museum_walkthrough.tscn"],["act1_broken_museum_jungle.json","res://scenes/lol2/jungle_walkthrough.tscn"]]:
			var source: String = earned.path_join(entry[0])
			if not check(FileAccess.file_exists(source),"earned save missing: " + source): return
			var bytes := FileAccess.get_file_as_bytes(source)
			var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256); ctx.update(bytes)
			var copy: String = DIR + "r13_" + entry[0]
			var out := FileAccess.open(copy, FileAccess.WRITE); out.store_buffer(bytes); out.close()
			var expected := Continuity.from_save(JSON.parse_string(bytes.get_string_from_utf8()))
			var area = await open_fresh(entry[1])
			if not await load_click(area, copy): return
			var errors := Continuity.compare(expected, Continuity.from_host(area))
			result.compatibility[entry[0]] = {"sha256": ctx.finish().hex_encode(), "errors": errors, "fields": expected.size()}
			if not check(errors.is_empty(),"%s loaded with differences: %s" % [entry[0], errors]): return
			await shot("r13_" + entry[0].get_basename())
			await finish(area)
	var file := FileAccess.open(DIR + "phase2.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ", true)); file.close()
	print("PASS player_continuity_restart: new process, Cave/Museum/Jungle saves loaded by real Load clicks equal their save-time snapshots (no allowed changes) and differ from a fresh start; HUD agrees after each. Earned R13 saves: %s" % (str(result.compatibility.keys()) if not earned.is_empty() else "not supplied"))
	quit()
