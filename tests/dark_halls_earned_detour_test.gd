extends SceneTree
## Earned Dark Halls detour (Act 1), four OS processes, each run with --phase=<name>:
##   enter  : earned repaired-monastery save (hash-pinned) -> monastery hall -> real mouse clicks on the MENT cellar
##            hotspot and the MCEL passage hotspot1 -> Dark Halls L7 entry1 -> F5 at arrival -> 426-waypoint walk
##            driven by W/Shift keys and mouse motion with the creature population ACTIVE (strikes by left click, Spark/
##            Heal by 1/2/Q) -> six dome windows by E -> F5 (actual Dark Halls quicksave) and quit.
##   finish : original game gate "Resume Dark Halls" on the prior process's quicksave (hash-checked) -> seventh window by
##            E -> walk into the hosted exit -> actual route transition to Jungle entry6 -> F5 (Jungle quicksave), quit.
##   depart : original game gate "Resume jungle" on that quicksave (hash-checked) -> walk entry6 to the monastery
##            entrance (actual MENT entry) -> Esc out -> source 174-region departure route -> first-use exit movie ->
##            darker jungle arrival -> F5 and the chain save; soul, puzzle, loot and inventory carried through.
##   resume : original game gate "Resume darker jungle" on that F5 save (hash-checked): items, soul, puzzle unchanged.
## Never sets health, items, quest state, positions or window states; never disables creatures or the route host.
## Receipts: user://tests/dark_halls_earned/<phase>.json (inputs/outputs sha256, combat log, health trace).
const Save = preload("res://scripts/lol2/jungle_save.gd")
const DarkHalls = preload("res://scripts/lol2/dark_halls.gd")
const Live = preload("res://scripts/lol2/creature_live_rules.gd")
const PopState = preload("res://scripts/lol2/scripted_creature_state.gd")
const Defaults = preload("res://scripts/lol2/shared_global_defaults.gd")
const JUNGLE := "res://scenes/lol2/jungle_walkthrough.tscn"
const HALLS := "res://scenes/lol2/dark_halls.tscn"
const GATE := "res://scenes/lol2/original_game_gate.tscn"
const DARKER := "res://scenes/lol2/darker_jungle.tscn"
const OUT := "user://tests/dark_halls_earned/"
const INPUT := "user://tests/act1_broken_repaired_monastery.json"
const JUNGLE_SAVE := "user://saves/jungle_quicksave.json"
const WINDOWS_FIRST := [246, 247, 251, 250, 249, 248]
const WINDOW_LAST := 237
const SENSITIVITY := 0.003
const HEAL_AT := 18 # Heal (+6) at or below this; one rat bite is 6.
## Loot controls next to the walk (dark_halls_loot_source.json): two Healing scrolls and a Prism scroll, taken by E.
## Each is approached from its nearest walk waypoint (968 from #29, 971 from #30); straight lines between them cross walls.
const LOOT_AFTER_WAYPOINT := 30
const LOOT := [[968, 29], [971, 30]]
var phase := ""
var receipt: Dictionary = {"passed": false, "combat": [], "health": [], "notes": []}
var keys: Dictionary = {}
var scene: Node = null
var last_health := -1
var stuck_reports := 0

func _initialize() -> void: run.call_deferred()

func fail(message: String) -> bool:
	release_keys()
	receipt.passed = false
	receipt.failure = message
	if scene != null and is_instance_valid(scene) and scene.get("player") != null:
		receipt.failure_position = [scene.player.position.x, scene.player.position.y, scene.player.position.z]
	write_receipt()
	push_error(message)
	print("FAIL dark_halls_earned_detour[", phase, "]: ", message)
	quit(1)
	return false

func write_receipt() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var file := FileAccess.open(OUT + phase + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  ") + "\n")
	file.close()

func note(text: String) -> void:
	receipt.notes.append(text)
	print("NOTE ", text)

# ---- ordinary input -------------------------------------------------------------------------------------------------
func set_key(code: Key, down: bool) -> void:
	if bool(keys.get(code, false)) == down: return
	keys[code] = down
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func release_keys() -> void:
	for code in keys.keys(): set_key(code, false)

func tap(code: Key) -> void:
	set_key(code, true)
	await process_frame
	set_key(code, false)
	await process_frame

func click_at(position: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = position
		e.global_position = position
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame

func click_control(control: Control) -> void:
	var centre: Vector2 = control.get_global_transform_with_canvas() * (control.size / 2.0)
	note("click %s at %s" % [control.get_meta("room", "?"), centre])
	await click_at(centre)

## Mouse motion that turns the view toward a world point (the host's own 0.003 rad/pixel look).
func look_toward(point: Vector3, pitch_too: bool = true) -> void:
	var cam: Camera3D = scene.camera
	var d: Vector3 = point - cam.global_position
	var yaw := atan2(-d.x, -d.z)
	var dyaw := wrapf(yaw - scene.player.rotation.y, -PI, PI)
	var dpitch := 0.0
	if pitch_too:
		var pitch := atan2(d.y, Vector2(d.x, d.z).length())
		dpitch = clampf(pitch, -1.4, 1.4) - cam.rotation.x
	else:
		dpitch = -0.05 - cam.rotation.x
	if absf(dyaw) < 0.0005 and absf(dpitch) < 0.0005: return
	var m := InputEventMouseMotion.new()
	m.relative = Vector2(-dyaw / SENSITIVITY, -dpitch / SENSITIVITY)
	Input.parse_input_event(m)
	Input.flush_buffered_events()

func ensure_captured() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: return
	# The world click handler captures the mouse, as a player clicks back into the view.
	var where: Vector3 = scene.player.position if is_instance_valid(scene) and scene.get("player") != null else Vector3.ZERO
	var departure_phase := str(scene.quest_state.get("act_one_departure", {}).get("phase", "")) if is_instance_valid(scene) and scene.get("quest_state") != null else ""
	var hud_cursor := bool(scene.interface_hud.cursor_active) if is_instance_valid(scene) and scene.get("interface_hud") != null else false
	note("mouse not captured (mode %d) at %s departure '%s' hud_cursor %s focus %s; world click" % [Input.mouse_mode, where, departure_phase, hud_cursor, root.has_focus()])
	await click_at(Vector2(640, 360))

# ---- scene helpers --------------------------------------------------------------------------------------------------
func wait_scene(path: String, previous: int = 0) -> Node:
	for i in 1800:
		await process_frame
		var s: Node = current_scene
		if s == null or s.get_instance_id() == previous or s.scene_file_path != path: continue
		if s.get("ready_for_review") == false: continue
		return s
	return null

func health() -> int:
	return int(scene.starting_magic.health())

func mana() -> int:
	return int(scene.starting_magic.magic_state().player.mana)

func trace_health(tag: String) -> void:
	var h := health()
	if h != last_health:
		receipt.health.append([tag, h, snappedf(Time.get_ticks_msec() / 1000.0, 0.01)])
		last_health = h

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT + "capture")
	root.get_texture().get_image().save_png(OUT + "capture/" + phase + "_" + name + ".png")

func file_sha(path: String) -> String:
	return FileAccess.get_sha256(path)

func copy_file(from: String, to: String) -> void:
	DirAccess.make_dir_recursive_absolute(to.get_base_dir())
	var data := FileAccess.get_file_as_bytes(from)
	var file := FileAccess.open(to, FileAccess.WRITE)
	file.store_buffer(data)
	file.close()

func globals() -> Dictionary:
	return scene.quest_state.get("monastery", {}).get("globals", {})

func soul() -> int:
	return int(Defaults.read(globals(), "GV_LUTHERS_SOUL"))

# ---- combat (Dark Halls population) ---------------------------------------------------------------------------------
func pop() -> Node:
	var p = scene.get("creatures")
	return p if p != null and is_instance_valid(p) else null

func threat(radius: float) -> String:
	var p := pop()
	if p == null: return ""
	var best := ""
	var best_d := radius
	var me: Vector3 = scene.player.global_position
	for id in p.bodies:
		if not PopState.ready_to_fight(p.state, p.src, id): continue
		var body: Node3D = p.bodies[id]
		var s: Vector3 = body.global_position - me
		if absf(s.y) > 90: continue
		var d := Vector2(s.x, s.z).length()
		var mode := int(p.state.live[id].mode)
		if mode == Live.IDLE and d > 70: continue
		if d < best_d: best_d = d; best = id
	return best

func aim_point(id: String) -> Vector3:
	var p := pop()
	var row: Dictionary = PopState.actor_row(p.src, id)
	var look: Dictionary = DarkHalls.CREATURE_CONFIG.look[str(int(row.definition))]
	return p.bodies[id].global_position + Vector3.UP * float(look.height) * 0.5

func select_spell(key: Key, spell: String) -> void:
	if str(scene.starting_magic.magic_state().get("spell", "spark")) != spell: await tap(key)

## Fight the nearest engaged creature until none is within radius. Ordinary input only: mouse look, left-click strikes
## when the strike ray is on the creature, Spark (1+Q) when it is beyond reach, Heal (2+Q) when health is low.
func fight(radius: float, tag: String) -> bool:
	var frames := 0
	var engaged := ""
	while true:
		var id := threat(radius)
		if id.is_empty():
			if not engaged.is_empty(): set_key(KEY_W, false)
			return true
		if id != engaged:
			engaged = id
			receipt.combat.append({"tag": tag, "actor": id, "name": pop().name_of(id), "health_before": int(pop().state.actors[id].health), "player": health(), "frame": frames})
			print("ENGAGE ", tag, " actor ", id, " ", pop().name_of(id), " player health ", health())
		frames += 1
		if frames > 60 * 120: return fail("Fight did not end near %s (actor %s)" % [tag, id])
		trace_health(tag)
		if health() <= 0: return fail("Player fell in combat at %s (actor %s)" % [tag, id])
		var magic: Node = scene.starting_magic
		var ready_to_cast: bool = float(magic.magic_state().get("cooldown", 0)) <= 0
		if health() <= HEAL_AT and mana() >= 2 and ready_to_cast:
			set_key(KEY_W, false)
			await select_spell(KEY_2, "heal")
			var before := health()
			await tap(KEY_Q)
			receipt.combat.append({"tag": tag, "heal": [before, health()], "mana": mana()})
			await select_spell(KEY_1, "spark")
			continue
		look_toward(aim_point(id))
		var body: Node3D = pop().bodies[id]
		var s: Vector3 = body.global_position - scene.player.global_position
		var d := Vector2(s.x, s.z).length()
		set_key(KEY_SHIFT, false)
		set_key(KEY_W, d > 70.0)
		await physics_frame
		if pop() == null: return true
		if pop().aimed() == id and float(pop().strike_remaining) <= 0.0:
			await click_at(Vector2(640, 360))
		elif d > 110.0 and d < 380.0 and mana() > 20 and ready_to_cast and str(magic.magic_state().get("spell", "spark")) == "spark":
			var hit_before := int(pop().state.actors[id].health)
			await tap(KEY_Q)
			if int(pop().state.actors[id].health) < hit_before: receipt.combat.append({"tag": tag, "spark": id, "health": int(pop().state.actors[id].health)})
	return true

# ---- walking --------------------------------------------------------------------------------------------------------
## Walk to a point with W (+Shift sprint) and mouse look; fight anything that engages within reach on the way.
func walk_to(target: Vector2, tolerance: float, max_frames: int, tag: String, combat: bool = true, stuck_ok: bool = false) -> bool:
	var best := INF
	var since_best := 0
	for frame in max_frames:
		var leaving: Node = scene.get_node_or_null("DarkHallsRoute") if is_instance_valid(scene) else null
		if not is_instance_valid(scene) or current_scene != scene or (leaving != null and bool(leaving.transitioning)):
			# A level change hands over to the next scene: let go of the keys, as a player does on a loading screen.
			release_keys()
			return true
		var rooms: Node = scene.get("monastery") if scene.get("monastery") != null and is_instance_valid(scene.get("monastery")) else null
		var leaving_movie: Node = scene.get("departure") if scene.get("departure") != null and is_instance_valid(scene.get("departure")) else null
		if (rooms != null and rooms.active()) or (leaving_movie != null and leaving_movie.active()):
			# A room view or the departure movie took over (walking into its source region): stop; the caller decides.
			release_keys()
			return true
		await ensure_captured()
		trace_health(tag)
		if health() <= 0: return fail("Player fell while walking at %s" % tag)
		var p: Vector3 = scene.player.position
		var offset := target - Vector2(p.x, p.z)
		var d := offset.length()
		if d < tolerance:
			set_key(KEY_W, false)
			return true
		if combat and not threat(95.0).is_empty():
			set_key(KEY_W, false)
			var left_route := Vector2(p.x, p.z)
			if not await fight(140.0, tag): return false
			# The fight steps toward each creature, off the walked line; a straight line from there to the target can
			# cut through scenery. Go back to where the fight began first, as a player returns to the path.
			var here: Vector3 = scene.player.position
			if Vector2(here.x, here.z).distance_to(left_route) > 8.0 and is_instance_valid(scene) and current_scene == scene:
				if not await walk_to(left_route, 6.0, max_frames, tag + "/rejoin", combat, stuck_ok): return false
			best = INF
			continue
		if d < best - 0.5: best = d; since_best = 0
		else: since_best += 1
		if since_best > 240:
			set_key(KEY_W, false)
			if stuck_ok: return true
			return fail("Walk stuck at %s: %.1f from %s, position %s" % [tag, d, target, p])
		look_toward(Vector3(target.x, p.y, target.y), false)
		set_key(KEY_SHIFT, d > 30.0)
		set_key(KEY_W, true)
		await physics_frame
	set_key(KEY_W, false)
	return fail("Walk timed out at %s" % tag)

func walk_points(points: Array, tag: String, tolerance: float = 6.0, from: int = 0, to: int = -1) -> bool:
	for k in range(from, points.size() if to < 0 else to):
		var target := Vector2(float(points[k][0]), float(points[k][1]))
		if not await walk_to(target, tolerance, 60 * 60, "%s#%d" % [tag, k]): return false
		var leaving: Node = scene.get_node_or_null("DarkHallsRoute") if is_instance_valid(scene) else null
		if not is_instance_valid(scene) or current_scene != scene or (leaving != null and bool(leaving.transitioning)): return true
	return true

# ---- Dark Halls loot (E on a source item-giving control) -------------------------------------------------------------
func take_loot(control: int) -> bool:
	var loot: Node = scene.loot
	var row: Dictionary = {}
	for c in loot.source.controls:
		if int(c.control) == control: row = c
	if row.is_empty(): return fail("No loot control %d" % control)
	var point := Vector3(float(row.position[0]), float(row.position[1]) + 24.0, float(row.position[2]))
	# Walk up to it; its own object box may stop the player first (stuck_ok), reach is checked below.
	if not await walk_to(Vector2(point.x, point.z), 45.0, 60 * 40, "loot%d" % control, true, true): return false
	if not await fight(260.0, "loot%d" % control): return false
	var taken: Array = []
	for grant in row.grants:
		var before: int = scene.carried_collected.size()
		for attempt in 30:
			look_toward(point)
			await physics_frame
			if int(loot.target().get("control", -1)) == control: break
		if int(loot.target().get("control", -1)) != control: return fail("Loot %d not targeted (camera %.1f away)" % [control, scene.camera.global_position.distance_to(point)])
		await tap(KEY_E)
		if scene.carried_collected.size() != before + 1 or not grant.id in scene.carried_collected: return fail("E did not take %s from control %d" % [grant.id, control])
		taken.append(grant.id)
	receipt.loot.append({"control": control, "taken": taken, "health": health()})
	print("LOOT ", control, " taken by E: ", taken)
	return true

# ---- Dark Halls window use ------------------------------------------------------------------------------------------
func open_window_by_e(control: int) -> bool:
	var windows: Node = scene.windows
	var w: Dictionary = windows.by_control[control]
	var centre: Vector3 = windows._vec(w.center)
	var stand: Vector3 = centre + windows._inward(w) * 70.0
	if not await walk_to(Vector2(stand.x, stand.z), 6.0, 60 * 60, "window%d" % control): return false
	if not await fight(260.0, "window%d" % control): return false
	for attempt in 30:
		look_toward(centre)
		await physics_frame
		if windows.aimed_window() == control: break
	if windows.aimed_window() != control: return fail("Window %d not aimed by mouse look" % control)
	await tap(KEY_E)
	if not control in windows.opened(): return fail("E did not open window %d" % control)
	receipt.windows.append({"control": control, "position": [scene.player.position.x, scene.player.position.y, scene.player.position.z], "health": health(), "soul": soul()})
	print("WINDOW ", control, " opened by E; health ", health(), " soul ", soul())
	return true

func f5() -> void:
	await tap(KEY_F5)
	for i in 3: await process_frame

func population_summary() -> Dictionary:
	var p := pop()
	var dead: Array = []
	var woken := 0
	for id in p.state.actors:
		if int(p.state.actors[id].health) == 0: dead.append(id)
		if bool(p.state.actors[id].woken): woken += 1
	return {"dead": dead, "woken": woken, "actors": p.state.actors.size()}

func gate_resume(label: String, path: String, expected_sha: String, destination: String) -> bool:
	if file_sha(path) != expected_sha: return fail("Prior-process save hash mismatch for %s" % path)
	change_scene_to_file(GATE)
	var gate: Node = await wait_scene(GATE)
	if gate == null: return fail("Gate did not open")
	for i in 12: await process_frame
	var button: Button = find_button(gate, label)
	if button == null: return fail("Gate has no '%s' button" % label)
	gate.path_field.text = OS.get_environment("LOL2_ORIGINAL_GAME_EXE") if not OS.get_environment("LOL2_ORIGINAL_GAME_EXE").is_empty() else "~/lol2_runtime_root/LOLG.EXE"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var gate_id := gate.get_instance_id()
	await click_control(button)
	scene = await wait_scene(destination, gate_id)
	if scene == null: return fail("'%s' did not load %s" % [label, destination])
	for i in 20: await physics_frame
	if file_sha(path) != expected_sha: return fail("Resume changed the source save")
	return true

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null: return found
	return null

# ---- phases ---------------------------------------------------------------------------------------------------------
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	if not phase in ["enter", "finish", "depart", "resume"]:
		phase = "invalid"
		fail("Use --phase=enter|finish|depart|resume")
		return
	receipt.phase = phase
	if FileAccess.file_exists(OUT + phase + ".json"): DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + phase + ".json"))
	receipt.windows = []
	receipt.loot = []
	receipt.pid = OS.get_process_id()
	receipt.source_commit = OS.get_environment("LOL2_SOURCE_COMMIT")
	root.grab_focus()
	if phase == "enter": await enter()
	elif phase == "finish": await finish()
	elif phase == "depart": await depart()
	else: await resume()

func enter() -> void:
	var expected := OS.get_environment("LOL2_DH_INPUT_SHA")
	if expected.is_empty():
		var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/broken-repair-earned-walk-checks.json"))
		expected = str(proof.get("output_sha256", "")) if proof is Dictionary else ""
	if expected.is_empty() or file_sha(INPUT) != expected: return fail("Earned monastery save missing or not the pinned witness")
	receipt.input = {"path": INPUT, "sha256": file_sha(INPUT)}
	change_scene_to_file(JUNGLE)
	scene = await wait_scene(JUNGLE)
	if scene == null: return fail("Jungle did not load")
	var error: String = scene.quickload(INPUT)
	if not error.is_empty(): return fail("Earned save load: " + error)
	for i in 10: await physics_frame
	var m: Node = scene.monastery
	if m.state().get("room", "") != "MENT": return fail("Earned save is not in the monastery hall: %s" % m.state().get("room", ""))
	var before: Dictionary = scene.area_handoff()
	receipt.before = {"soul": soul(), "items": before.inventory.collected.duplicate(), "health": health(), "mana": mana(), "globals": globals().duplicate()}
	# Hall -> cellar by the hall's own cellar hotspot (mouse click on the room view).
	var cellar: Control = null
	for hit in m.hotspots:
		if hit.get_meta("room", "") == "MENT" and hit.visible and Rect2(hit.position, hit.size).is_equal_approx(Rect2(0, 106, 87, 227)): cellar = hit
	if cellar == null: return fail("No visible MENT cellar hotspot")
	await click_control(cellar)
	for i in 5: await process_frame
	if m.state().get("room", "") != "MCEL": return fail("Cellar click did not enter MCEL (room %s)" % m.state().get("room", ""))
	await capture("cellar")
	for i in 60 * 120:
		await process_frame
		if not m.Speech.active(m.state().get("conversation", m.Speech.initial())): break
	if m.Speech.active(m.state().get("conversation", m.Speech.initial())): return fail("Cellar conversation did not end")
	var passage: Control = null
	for hit in m.hotspots:
		if hit.get_meta("room", "") == "MCEL" and hit.visible: passage = hit
	if passage == null: return fail("No visible MCEL hotspot1")
	var previous: int = scene.get_instance_id()
	await click_control(passage)
	scene = await wait_scene(HALLS, previous)
	if scene == null: return fail("Cellar hotspot1 did not load Dark Halls")
	for i in 20: await physics_frame
	var route: Node = scene.get_node("DarkHallsRoute")
	var arrival: Array = route.catalog().routes.jungle[0].arrival
	if Vector2(scene.player.position.x - arrival[0], scene.player.position.z - arrival[2]).length() > 2 or not scene.player.is_on_floor(): return fail("Not grounded at L7 entry1")
	if pop() == null or pop().bodies.size() != 51: return fail("Dark Halls population missing")
	if not pop().is_physics_processing() or not route.is_physics_processing() or not scene.is_physics_processing(): return fail("A Dark Halls host is not processing")
	var carried: Dictionary = scene.area_handoff()
	if carried.inventory.collected != before.inventory.collected or carried.quests.monastery.globals != before.quests.monastery.globals: return fail("Cellar handoff changed items or globals")
	await capture("arrival")
	last_health = -1
	trace_health("arrival")
	await ensure_captured()
	await f5()
	if not FileAccess.file_exists(DarkHalls.DEFAULT_PATH): return fail("F5 did not write the Dark Halls quicksave at arrival")
	receipt.arrival_save = {"sha256": file_sha(DarkHalls.DEFAULT_PATH)}
	copy_file(DarkHalls.DEFAULT_PATH, OUT + "enter_arrival_quicksave.json")
	var walk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/dark_halls_walk_path.json"))
	if not await walk_points(walk.points, "walk", 6.0, 0, LOOT_AFTER_WAYPOINT + 1): return
	for pair in LOOT:
		var via: Array = walk.points[int(pair[1])]
		if not await walk_to(Vector2(float(via[0]), float(via[1])), 6.0, 60 * 60, "loot_via#%d" % int(pair[1])): return
		if not await take_loot(int(pair[0])): return
	if not await walk_points(walk.points, "walk", 6.0, LOOT_AFTER_WAYPOINT): return
	if not route.inside_route(route.routes[route.routes.size() - 1]): note("walk ended outside the last exit polygon")
	receipt.walk = {"waypoints": walk.points.size(), "resets": int(scene.resets), "health": health(), "mana": mana(), "position": [scene.player.position.x, scene.player.position.y, scene.player.position.z]}
	await capture("dome")
	for control in WINDOWS_FIRST:
		if not await open_window_by_e(control): return
	if scene.windows.done() or scene.windows.opened().size() != 6: return fail("Puzzle state after six windows: %s" % [scene.windows.opened()])
	if not await fight(300.0, "before_save"): return
	await f5()
	var path: String = DarkHalls.DEFAULT_PATH
	var check := Save.read_save(path, DarkHalls.FORMAT)
	if not str(check.error).is_empty(): return fail("Dark Halls quicksave unreadable: " + str(check.error))
	if check.state.quests.dark_halls_windows.opened.size() != 6: return fail("Quicksave lacks the six windows")
	receipt.output = {"path": path, "sha256": file_sha(path)}
	copy_file(path, OUT + "enter_output_quicksave.json")
	receipt.after = {"soul": soul(), "items": scene.carried_collected.duplicate(), "health": health(), "mana": mana(), "population": population_summary(), "resets": int(scene.resets), "windows": scene.windows.opened().duplicate()}
	receipt.passed = true
	release_keys()
	write_receipt()
	print("PASS dark_halls_earned_detour[enter]: earned cellar clicks -> Dark Halls with active creatures, ", receipt.combat.size(), " combat records, 426-waypoint input walk, six windows by E, F5 save ", receipt.output.sha256)
	quit(0)

## The prior phase's output hash: LOL2_DH_PRIOR_SHA, else the prior phase receipt (chain legs).
func prior_sha(previous_phase: String) -> String:
	var expected := OS.get_environment("LOL2_DH_PRIOR_SHA")
	if not expected.is_empty(): return expected
	var prior: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT + previous_phase + ".json"))
	if not prior is Dictionary or not bool(prior.get("passed", false)): return ""
	return str(prior.get("output", {}).get("sha256", ""))

func finish() -> void:
	var expected := prior_sha("enter")
	if not await gate_resume("Resume Dark Halls", DarkHalls.DEFAULT_PATH, expected, HALLS): return
	receipt.input = {"path": DarkHalls.DEFAULT_PATH, "sha256": expected}
	var saved := Save.read_save(DarkHalls.DEFAULT_PATH, DarkHalls.FORMAT)
	if scene.windows.opened().size() != 6 or scene.windows.done(): return fail("Resume lost the six windows")
	if scene.carried_collected != saved.state.inventory.collected or soul() != int(saved.state.quests.monastery.globals.GV_LUTHERS_SOUL): return fail("Resume changed inventory or soul")
	if pop() == null or not pop().is_physics_processing(): return fail("Population not active after resume")
	receipt.before = {"soul": soul(), "items": scene.carried_collected.duplicate(), "health": health(), "mana": mana(), "population": population_summary()}
	last_health = -1
	trace_health("resume")
	await ensure_captured()
	if not await open_window_by_e(WINDOW_LAST): return
	if not scene.windows.done(): return fail("Seventh window did not finish the puzzle")
	if soul() != int(receipt.before.soul) + 1: return fail("Puzzle soul reward %d -> %d" % [receipt.before.soul, soul()])
	receipt.puzzle = {"soul": soul(), "population": population_summary()}
	await capture("puzzle_done")
	var route: Node = scene.get_node("DarkHallsRoute")
	var exit_route: Dictionary = route.routes[0]
	var centre := Vector2.ZERO
	for q in exit_route.polygon: centre += Vector2(float(q[0]), float(q[1]))
	centre /= float(exit_route.polygon.size())
	receipt.exit_route = {"region": int(exit_route.region), "centre": [centre.x, centre.y]}
	var halls: Node = scene
	if not await walk_to(centre, 4.0, 60 * 90, "exit"): return
	var back: Node = null
	for i in 600:
		await process_frame
		if current_scene != null and current_scene != halls and current_scene.scene_file_path == JUNGLE and current_scene.get("ready_for_review"):
			back = current_scene; break
	release_keys()
	if back == null: return fail("Dark Halls exit did not return to the Jungle")
	scene = back
	for i in 30: await physics_frame
	var entry6: Array = preload("res://scripts/lol2/dark_halls_route.gd").catalog().routes.dark_halls[0].arrival
	if Vector2(scene.player.position.x - entry6[0], scene.player.position.z - entry6[2]).length() > 2 or not scene.player.is_on_floor(): return fail("Not grounded at Jungle entry6: %s" % scene.player.position)
	if not bool(scene.quest_state.get("dark_halls_windows", {}).get("done", false)) or soul() != int(receipt.puzzle.soul): return fail("Return lost the puzzle or soul")
	await capture("jungle_entry6")
	await ensure_captured()
	await f5()
	var check := Save.read_save(JUNGLE_SAVE)
	if not str(check.error).is_empty(): return fail("Jungle quicksave unreadable: " + str(check.error))
	receipt.output = {"path": JUNGLE_SAVE, "sha256": file_sha(JUNGLE_SAVE)}
	copy_file(JUNGLE_SAVE, OUT + "finish_output_jungle_quicksave.json")
	receipt.after = {"soul": soul(), "items": scene.carried_collected.duplicate(), "health": health(), "mana": mana(), "position": [scene.player.position.x, scene.player.position.y, scene.player.position.z], "dark_halls_windows": scene.quest_state.dark_halls_windows.duplicate(true), "dark_halls_loot": scene.quest_state.get("dark_halls_loot", {}).duplicate(true)}
	receipt.passed = true
	write_receipt()
	print("PASS dark_halls_earned_detour[finish]: gate resumed prior-process Dark Halls save, seventh window by E (soul ", receipt.before.soul, " -> ", soul(), "), walked exit to Jungle entry6, F5 ", receipt.output.sha256)
	quit(0)

func depart() -> void:
	var expected := prior_sha("finish")
	if not await gate_resume("Resume jungle", JUNGLE_SAVE, expected, JUNGLE): return
	receipt.input = {"path": JUNGLE_SAVE, "sha256": expected}
	var saved := Save.read_save(JUNGLE_SAVE)
	if scene.carried_collected != saved.state.inventory.collected or soul() != int(saved.state.quests.monastery.globals.GV_LUTHERS_SOUL): return fail("Jungle resume changed inventory or soul")
	if not bool(scene.quest_state.get("dark_halls_windows", {}).get("done", false)): return fail("Jungle resume lost the Dark Halls puzzle")
	receipt.before = {"soul": soul(), "items": scene.carried_collected.duplicate(), "health": health()}
	await ensure_captured()
	var to_hall: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dark_halls_entry6_monastery_route.json"))
	for k in to_hall.points.size():
		if scene.monastery.active(): break
		var t := Vector2(float(to_hall.points[k][0]), float(to_hall.points[k][1]))
		if not await walk_to(t, 6.0, 60 * 60, "to_hall#%d" % k, false): return
	for i in 120:
		if scene.monastery.active(): break
		await physics_frame
	release_keys()
	if scene.monastery.state().get("room", "") != "MENT": return fail("Walk from entry6 did not enter the monastery hall (room '%s')" % scene.monastery.state().get("room", ""))
	await capture("hall")
	await tap(KEY_ESCAPE)
	for i in 10: await process_frame
	if scene.monastery.active(): return fail("Esc did not leave the monastery hall")
	await ensure_captured()
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/act_one_departure_route.json"))
	var inventory: Array = scene.carried_collected.duplicate()
	for k in route.points.size():
		if current_scene != scene or scene.departure.active(): break
		var t := Vector2(float(route.points[k][0]), float(route.points[k][1]))
		if not await walk_to(t, 6.0, 60 * 60, "departure#%d" % k, false): return
	release_keys()
	var jungle: Node = scene
	var darker: Node = null
	for i in 60 * 60:
		await process_frame
		if current_scene != null and current_scene != jungle and current_scene.scene_file_path == DARKER:
			darker = current_scene; break
		if is_instance_valid(jungle) and current_scene == jungle and not jungle.departure.active() and i % 60 == 59:
			note("departure not active after route; continuing on foot")
			if not await walk_to(Vector2(float(route.points[-1][0]), float(route.points[-1][1])), 3.0, 600, "departure_end", false): return
	if darker == null: return fail("Departure did not reach the darker jungle")
	scene = darker
	for i in 60: await physics_frame
	if scene.carried_collected != inventory or soul() != int(receipt.before.soul) or not bool(scene.quest_state.get("dark_halls_windows", {}).get("done", false)): return fail("Darker jungle arrival lost items, soul or the Dark Halls puzzle")
	await ensure_captured()
	await f5()
	var darker_f5 := str(preload("res://scripts/lol2/darker_jungle.gd").DEFAULT_PATH)
	var f5_check := Save.read_save(darker_f5, scene.area_save_format)
	if not str(f5_check.error).is_empty(): return fail("F5 in the darker jungle: " + str(f5_check.error))
	receipt.darker_f5 = {"path": darker_f5, "sha256": file_sha(darker_f5)}
	copy_file(darker_f5, OUT + "depart_darker_f5_quicksave.json")
	var output := "user://tests/act1_dark_halls_darker_arrival.json"
	var error: String = scene.quicksave(output)
	if not error.is_empty():
		# Keep the refused state for review: the bytes the save writer would have written (not a save file).
		var refused := JSON.stringify({"format": scene.area_save_format, "version": 1, "inventory": scene.inventory_state(), "quests": scene.quest_state, "player": {"position": [scene.player.position.x, scene.player.position.y, scene.player.position.z], "yaw": wrapf(scene.player.rotation.y, -PI, PI), "pitch": scene.camera.rotation.x}}, "  ", true, true) + "\n"
		var dump := FileAccess.open(OUT + "depart_refused_state.json.txt", FileAccess.WRITE)
		dump.store_string(refused)
		dump.close()
		receipt.refused_bytes = refused.to_utf8_buffer().size()
		return fail("Darker jungle save: " + error)
	receipt.output = {"path": output, "sha256": file_sha(output)}
	copy_file(output, OUT + "depart_output_darker_arrival.json")
	receipt.after = {"soul": soul(), "items": scene.carried_collected.duplicate(), "health": health(), "dark_halls_windows": scene.quest_state.dark_halls_windows.duplicate(true), "departure": scene.quest_state.get("act_one_departure", null)}
	receipt.passed = true
	write_receipt()
	print("PASS dark_halls_earned_detour[depart]: gate resumed post-detour Jungle save, walked to the hall and out, departure movie, darker jungle with soul ", soul(), " and ", inventory.size(), " items; save ", receipt.output.sha256)
	quit(0)

## Fourth process: the original gate resumes the darker-jungle F5 save written at the end of the detour.
func resume() -> void:
	var prior: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUT + "depart.json"))
	var expected := OS.get_environment("LOL2_DH_PRIOR_SHA")
	if expected.is_empty() and prior is Dictionary and bool(prior.get("passed", false)): expected = str(prior.get("darker_f5", {}).get("sha256", ""))
	var path := str(preload("res://scripts/lol2/darker_jungle.gd").DEFAULT_PATH)
	if not await gate_resume("Resume darker jungle", path, expected, DARKER): return
	receipt.input = {"path": path, "sha256": expected}
	var saved := Save.read_save(path, scene.area_save_format)
	if not str(saved.error).is_empty(): return fail("Darker F5 save: " + str(saved.error))
	if scene.carried_collected != saved.state.inventory.collected or soul() != int(saved.state.quests.monastery.globals.GV_LUTHERS_SOUL): return fail("Darker resume changed inventory or soul")
	if scene.quest_state.get("dark_halls_windows", {}) != saved.state.quests.dark_halls_windows or not bool(scene.quest_state.dark_halls_windows.done): return fail("Darker resume lost the Dark Halls puzzle")
	if scene.quest_state.get("dark_halls_population", {}).is_empty(): return fail("Darker resume dropped the Dark Halls population state")
	await capture("darker_resumed")
	receipt.after = {"soul": soul(), "items": scene.carried_collected.duplicate(), "health": health(), "dark_halls_windows": scene.quest_state.dark_halls_windows.duplicate(true), "position": [scene.player.position.x, scene.player.position.y, scene.player.position.z]}
	receipt.output = {"path": path, "sha256": file_sha(path)}
	receipt.passed = true
	write_receipt()
	print("PASS dark_halls_earned_detour[resume]: gate resumed the darker-jungle F5 save of the detour (soul ", soul(), ", ", scene.carried_collected.size(), " items, seven windows) unchanged")
	quit(0)
