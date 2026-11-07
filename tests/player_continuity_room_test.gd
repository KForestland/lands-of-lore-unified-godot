extends "res://tests/player_continuity_restart_test.gd"
## Jungle -> village room overlays -> Jungle continuity (matrix case 3; docs/player-continuity.md). Run with
## --demo-interface and LOL2_EARNED_SAVES; player_continuity_room_restart_test follows in a NEW process.
## START: the R13 earned Jungle save act1_broken_museum_jungle.json loaded with a real HUD Load click.
## EARNED with ordinary input (as tavern_liz_ordinary_route_test): production move_grounded walks the follow-up arm and
## into region 3501 (VILLAGE); real viewport clicks open CAN (Escape farewell) and LIZ, and take one beehive wax.
## SUPPLIED, labelled: S1 main village gate open (local24=1, pose 100); S2 start at the village_to_followup point 0.
## Checks: player snapshots at VILLAGE entry, after CAN, after the wax and back in the world. The only allowed player
## changes are the one new wax item and time-bounded mana regeneration. The world save is made with the HUD Save button.
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
const BeeWax = preload("res://scripts/lol2/jungle_beehive_wax.gd")
const VillageState = preload("res://scripts/lol2/jungle_village_state.gd")
const SAVE := "act1_broken_museum_jungle.json"
var scene
var rooms
var routes: Dictionary
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
func walk(points: Array, label: String, until: Callable = Callable()) -> bool:
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
		if not reached: return check(false, "%s blocked at waypoint %d target %s player %s" % [label, i, target, scene.player.position])
	return true
## Compare against the start snapshot, allowing only the listed new wax, My Journal notes the route has earned
## (journal_notes) and bounded regeneration.
var journal_notes: Array = []
func step(name: String, start: Dictionary, departed: float, remainder: float, wax: Array) -> bool:
	var allowed := {"magic.mana": mana_drift(start, departed, remainder)}
	for id in wax: allowed["collected[%s]" % id] = 1
	for id in journal_notes: allowed["journal[%s]" % id] = 1
	var now := Continuity.from_host(scene)
	receipt.snapshots[name] = now
	return compare(name, start, now, allowed)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var earned := OS.get_environment("LOL2_EARNED_SAVES")
	if not check(not earned.is_empty() and FileAccess.file_exists(earned.path_join(SAVE)),"LOL2_EARNED_SAVES with %s required" % SAVE): return
	var bytes := FileAccess.get_file_as_bytes(earned.path_join(SAVE))
	var copy := DIR + "room_start_" + SAVE
	var out := FileAccess.open(copy, FileAccess.WRITE); out.store_buffer(bytes); out.close()
	receipt.labels = {"start": SAVE, "earned": ["walk (move_grounded) follow-up arm and region 3501", "CAN click + Escape farewell", "LIZ click", "wax click", "Escape x2 to the world", "HUD Load/Save clicks"],
		"supplied": ["S1 main village gate open (local24=1, pose 100)", "S2 start at village_to_followup point 0"]}
	scene = await open_fresh("res://scenes/lol2/jungle_walkthrough.tscn")
	if not await load_click(scene, copy): return
	rooms = scene.monastery
	routes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_quest_walk_routes.json"))
	Engine.time_scale = 4.0; Engine.physics_ticks_per_second = 240
	scene.set_process_unhandled_input(true)
	scene.village_gate.state().local24 = 1; scene.village_gate.state().elapsed = VillageState.DURATION; scene.village_gate.restore()
	var p0: Array = routes.village_to_followup.points[0]
	scene.player.position = Vector3(p0[0], 32, p0[1]); scene.player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 4: await physics_frame
	var start := Continuity.from_host(scene)
	var remainder: float = float(scene.starting_magic.magic_state().get("regen_elapsed", 0.0))
	var departed := simulated_seconds
	receipt.snapshots.start = start
	if not await walk(routes.village_to_followup.points, "village_to_followup"): return
	for i in range(600):
		await physics_frame
		scene.move_grounded(Vector3.FORWARD, scene.player.get_physics_process_delta_time())
		if scene.followup_dialogue.active(): break
	for i in range(40000):
		await physics_frame
		if not scene.followup_dialogue.active() and scene.followup_gate.pose == 0: break
	if not await walk(routes.followup_to_tavern.points, "followup_to_tavern", func(): return rooms.active()): return
	if not check(rooms.active() and bank().room == "VILLAGE","village entry: room '%s'" % bank().room): return
	if not check(await settle(), "TAVERN intro did not finish"): return
	if not await step("village_entry", start, departed, remainder, []): return
	await process_frame
	if not check(click_hotspot("VILLAGE", Rect2(244,220,142,90)) and bank().room == "CAN", "CAN click: room '%s'" % bank().room): return
	if not check(await settle(), "CAN conversation did not finish"): return
	await escape()
	if not check(await settle() and bank().room == "VILLAGE", "CAN farewell"): return
	# Leaving CAN after the farewell records the note (monastery_rooms.JOURNAL_SEQUENCES.CAN_EXIT).
	journal_notes.append("tavern_after_farewell")
	if not await step("after_can", start, departed, remainder, []): return
	var wax_before: Array = scene.carried_collected.filter(func(i): return BeeWax.valid(i))
	if not check(click_hotspot("VILLAGE", Rect2(425,211,151,99)) and bank().room == "LIZ", "LIZ click: room '%s'" % bank().room): return
	if not check(await settle(), "LIZTRAN did not finish"): return
	if not check(await settle(), "LIZ entry cue did not finish"): return
	if not check(click_hotspot("LIZ", Rect2(91,282,55,57)), "wax click"): return
	var wax: Array = scene.carried_collected.filter(func(i): return BeeWax.valid(i) and i not in wax_before)
	if not check(wax.size() == 1, "wax click added %d items" % wax.size()): return
	await settle()
	if not await step("after_wax", start, departed, remainder, wax): return
	await escape(); await escape()
	for i in 4: await physics_frame
	if not check(not rooms.active() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "back to the world: room '%s'" % bank().room): return
	if not await step("world_return", start, departed, remainder, wax): return
	Engine.time_scale = 1.0; Engine.physics_ticks_per_second = 60
	for i in 4: await physics_frame
	if not await agrees_room(): return
	if not await save_click(scene, "room_jungle"): return
	var file := FileAccess.open(DIR + "room_phase1.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  ", true)); file.close()
	print("PASS player_continuity_room: R13 earned Jungle save -> walked VILLAGE entry, CAN, LIZ, wax by clicks -> world; player state unchanged except the one wax %s and time-bounded regen at every step; HUD agrees; saved." % [wax])
	quit()
func agrees_room() -> bool:
	var hud = scene.interface_hud; var magic = scene.starting_magic
	await cursor(hud, true)
	if not hud.sheet.visible or hud.atlas.visible: await click(hud.buttons[0])
	var fighting: Dictionary = magic.fighting_state()
	var ok: bool = ("Health: %d / 30" % magic.health()) in hud.sheet_body.text and ("Fighting: level %d (%d XP)" % [int(fighting.level), int(fighting.experience)]) in hud.sheet_body.text
	await shot("room_world_return")
	hud.close_sheet(); await cursor(hud, false)
	return check(ok, "HUD disagrees after rooms: '%s'" % hud.sheet_body.text)
