extends "res://tests/player_continuity_restart_test.gd"
## Tavern-doorway save/load (docs/tavern-return.md). Run with --demo-interface.
## START: with LOL2_EARNED_SAVES, the R13 earned Jungle save act1_broken_museum_jungle.json loaded with a real HUD
## Load click; otherwise a fresh Jungle scene (receipt.labels.start says which).
## SUPPLIED, labelled: S1 main village gate open (local24=1, pose 100); S2 the player is placed on the tavern approach
## (follow-up route waypoint A, outside region 3501).
## EARNED with ordinary input: production move_grounded walks into region 3501 (VILLAGE opens), Escape returns to the
## world while still standing in the doorway, and the HUD Save button writes the doorway save.
## Checks: a FRESH Jungle scene loading that save by HUD Load stays in the world (no VILLAGE re-entry, Left_Village and
## the player state unchanged); walking out of the doorway and back in still opens VILLAGE.
const VillageState = preload("res://scripts/lol2/jungle_village_state.gd")
const SAVE := "act1_broken_museum_jungle.json"
const A := Vector2(-1751.0, -4006.5)
const B := Vector2(-1630.0, -3900.0)
const VILLAGE := [Vector2(-1624,-4037),Vector2(-1565,-4021),Vector2(-1613,-3732),Vector2(-1729,-3790)]
func in_doorway(area) -> bool: return Geometry2D.is_point_in_polygon(Vector2(area.player.position.x, area.player.position.z), PackedVector2Array(VILLAGE))
func walk_to(area, target: Vector2, until: Callable = Callable()) -> bool:
	for tick in 2400:
		await physics_frame
		if until.is_valid() and until.call(): return true
		var offset := target - Vector2(area.player.position.x, area.player.position.z)
		if offset.length() < 3: return true
		var delta: float = area.player.get_physics_process_delta_time()
		var direction := offset.normalized() * minf(1, offset.length() / (80 * delta))
		area.move_grounded(Vector3(direction.x, 0, direction.y), delta)
		if area.resets != 0 or area.flying: return check(false, "walk to %s: reset/flight" % target)
	return check(false, "walk to %s blocked at %s" % [target, area.player.position])
func settle(area) -> void:
	for i in 20000:
		if not preload("res://scripts/lol2/monastery_conversation.gd").active(area.monastery.state().get("conversation", {"sequence":"","cursor":0})): return
		await physics_frame
func escape() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.keycode = KEY_ESCAPE; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
	for i in 4: await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var earned := OS.get_environment("LOL2_EARNED_SAVES")
	var area = await open_fresh("res://scenes/lol2/jungle_walkthrough.tscn")
	receipt.labels.start = "fresh Jungle scene"
	if not earned.is_empty():
		if not check(FileAccess.file_exists(earned.path_join(SAVE)),"LOL2_EARNED_SAVES lacks %s" % SAVE): return
		var copy := DIR + "doorway_start_" + SAVE
		var out := FileAccess.open(copy, FileAccess.WRITE); out.store_buffer(FileAccess.get_file_as_bytes(earned.path_join(SAVE))); out.close()
		if not await load_click(area, copy): return
		receipt.labels.start = SAVE
	area.set_process_unhandled_input(true)
	area.village_gate.state().local24 = 1; area.village_gate.state().elapsed = VillageState.DURATION; area.village_gate.restore()
	area.player.position = Vector3(A.x, 40, A.y); area.player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 30: await physics_frame
	if not check(not area.monastery.active() and not in_doorway(area) and area.resets == 0, "placement at A: room '%s'" % area.monastery.state().room): return
	# Earned entry: walk into region 3501.
	if not await walk_to(area, B, func(): return area.monastery.active()): return
	if not check(area.monastery.active() and area.monastery.state().room == "VILLAGE", "walk did not open VILLAGE"): return
	await settle(area)
	await escape()
	for i in 10: await physics_frame
	if not check(not area.monastery.active() and in_doorway(area), "Escape did not return to the world in the doorway (room '%s', doorway %s)" % [area.monastery.state().room, in_doorway(area)]): return
	if not await save_click(area, "doorway"): return
	var saved: Dictionary = receipt.saves.doorway
	var left_village: int = int(area.monastery.state().locals.get("Left_Village", 0))
	await finish(area)
	# Fresh scene, real Load click.
	area = await open_fresh("res://scenes/lol2/jungle_walkthrough.tscn")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saved.path))
	var disk_magic: Dictionary = disk.inventory.get("magic", disk.get("quests", {}).get("player_magic_reward_state", {}))
	var load_started := simulated_seconds
	if not await load_click(area, saved.path): return
	area.set_process_unhandled_input(true)
	for i in 60: await physics_frame
	# Mana may regenerate during the 60 frames; allowed only when the save carries magic (a fresh start has none).
	var allowed := {}
	if saved.snapshot.has("magic.mana"):
		if not check(saved.snapshot.has("magic.maximum") and disk_magic.has("regen_elapsed"), "missing saved mana maximum or regeneration clock"): return
		allowed["magic.mana"] = mana_drift(saved.snapshot, load_started, float(disk_magic.regen_elapsed))
	var result := {"room_after_load": str(area.monastery.state().room), "doorway": in_doorway(area), "left_village": int(area.monastery.state().locals.get("Left_Village", 0)),
		"diff": Continuity.compare(Continuity._normalized(saved.snapshot), Continuity.from_host(area), allowed)}
	receipt.doorway = result
	print("DOORWAY ", JSON.stringify(result))
	if not check(result.doorway, "load did not restore the doorway position"): return
	if not check(result.room_after_load == "" and not area.monastery.active(), "load at the tavern doorway re-entered '%s'" % result.room_after_load): return
	if not check(result.left_village == left_village and result.diff.is_empty(), "load changed state: Left_Village %d->%d diff %s" % [left_village, result.left_village, result.diff]): return
	if not check(area.interface_hud.visible, "HUD hidden after doorway load"): return
	await shot("doorway_after_load")
	# Entry still works after the load: walk out, then back in.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not await walk_to(area, A): return
	if not check(not area.monastery.active(), "walking out opened a room"): return
	if not await walk_to(area, B, func(): return area.monastery.active()): return
	if not check(area.monastery.active() and area.monastery.state().room == "VILLAGE", "re-entry after the doorway load did not open VILLAGE"): return
	await settle(area); await escape()
	var file := FileAccess.open(DIR + "doorway.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  ", true)); file.close()
	print("PASS village_doorway_load (start: %s): doorway save (walked in, Escape, HUD Save) loads in a fresh scene without re-entering VILLAGE; state unchanged; walking out and back in still opens VILLAGE. %s" % [receipt.labels.start, JSON.stringify(result)])
	quit()
