extends SceneTree
## Readable Atlas for the Darker Jungle (owner 2026-11-08, same rules as the Jungle): the native arrival from the Huline Jungle
## (-4577, 1168), M; the earned walk toward the Huline Temple (tests/fixtures/l8_first_departure_walk.json temple route up to the
## point before the door), M. Explored-only walls, "Back to the Huline Jungle" at the arrival, the temple door after the walk, the
## far places (Tribal Clubhouse, Wild Village, Larkhon's pass) hidden; the "see the temple first" note marks the temple door and
## clears when l8_journey.temple_visited is set; a full (old-save) area shows every L8 place and exit.
const Places := preload("res://scripts/lol2/atlas_places.gd")
const MyJournal := preload("res://scripts/lol2/my_journal.gd")
## Route points up to (not including) the temple door itself: the door's own encounter is l8_temple_earned_test.
const TEMPLE_STOP := 45
var scene
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL atlas readable l8: ", label)
	return ok

func report() -> Dictionary:
	return scene.interface_hud.atlas.readable_report()

func open_atlas() -> void:
	var hud = scene.interface_hud
	if not (hud.sheet.visible and hud.atlas.visible): hud.toggle_atlas()
	for i in 6: await process_frame

func walk(points: Array) -> bool:
	for i in points.size():
		var to := Vector2(float(points[i][0]), float(points[i][1]))
		var reached := false
		for f in 900:
			var off := to - Vector2(scene.player.global_position.x, scene.player.global_position.z)
			if off.length() < 6.0:
				reached = true
				break
			scene.move_grounded(Vector3(off.x, 0.0, off.y).normalized(), 1.0 / 60.0)
			await physics_frame
		if not reached:
			var hits := ""
			for j in scene.player.get_slide_collision_count():
				var c: KinematicCollision3D = scene.player.get_slide_collision(j)
				hits += " %s %s" % [c.get_collider().name, c.get_normal()]
			print("WALK HITS", hits, " paused ", paused)
		if not check(reached, "walk stuck before point %d %s at %s" % [i, str(points[i]), scene.player.global_position]): return false
	return true

func run() -> void:
	scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not check(scene.get("ready_for_review"), "Darker Jungle ready"): quit(1); return
	scene.set_physics_process(false)
	for i in 10: await physics_frame
	await open_atlas()
	var first := report()
	check(bool(first.get("filtering", false)), "a new arrival filters the Atlas to explored regions")
	check(int(first.get("blocked", 0)) > 0, "the L8 impassable regions are known to the Atlas (%d)" % int(first.get("blocked", 0)))
	check("l8_entry" in first.get("exits", []), "the way back to the Huline Jungle shows at the arrival")
	check(not ("clubhouse" in first.get("places", [])) and not ("wild_village" in first.get("places", [])), "the clubhouse and the village are not shown before they are explored")
	check(first.get("plot", []).is_empty(), "no plot marker before a Journal note")
	var start_explored: int = int(first.get("explored", 0))
	var start_walls: int = int(first.get("walls", 0))
	scene.interface_hud.close_sheet()
	# The Daniel meeting at the entry is its own earned test (l8_village_guard_first_approach sets the same precondition):
	# the blade is already recovered, so the encounter does not hold the walk.
	scene.quest_state["l8_journey"] = {"version": 1, "gift": "recovered", "temple_visited": false, "admitted": false, "key_awarded": false}
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_first_departure_walk.json"))
	var route: Array = (fixture.temple as Array).slice(0, TEMPLE_STOP)
	if not await walk(route): quit(1); return
	await open_atlas()
	var after := report()
	check(int(after.get("explored", 0)) > start_explored and int(after.get("walls", 0)) > start_walls, "the walk explored more regions and drew more wall lines (%d -> %d regions, %d -> %d walls)" % [start_explored, int(after.get("explored", 0)), start_walls, int(after.get("walls", 0))])
	check("temple_door" in after.get("exits", []), "the Huline Temple shows after walking up to its door")
	check(not ("wild_village" in after.get("places", [])) and not ("clubhouse" in after.get("places", [])) and not ("larkhon_pass" in after.get("exits", [])), "Wild Village, Tribal Clubhouse and the Larkhon pass stay hidden")
	MyJournal.discover(scene, "l8_see_temple_first")
	for i in 4: await process_frame
	check("l8_see_temple_first" in report().get("plot", []), "the temple-first note puts a plot marker at the temple door")
	if not scene.quest_state.has("l8_journey"): scene.quest_state.l8_journey = preload("res://scripts/lol2/l8_journey_state.gd").initial()
	scene.quest_state.l8_journey.temple_visited = true
	for i in 4: await process_frame
	check(not ("l8_see_temple_first" in report().get("plot", [])), "the marker clears once the temple is visited")
	scene.atlas_explored = {"version": 1, "areas": {"L8_SJ": {"full": true, "regions": []}}}
	for i in 4: await process_frame
	var full := report()
	var all_places := 0
	var all_exits := 0
	for row in Places.places("L8_SJ"):
		if str(row.get("kind", "place")) == "exit": all_exits += 1
		else: all_places += 1
	check(full.get("places", []).size() == all_places and full.get("exits", []).size() == all_exits, "a full area shows every place (%d of %d) and exit (%d of %d)" % [full.get("places", []).size(), all_places, full.get("exits", []).size(), all_exits])
	check(Places.step_done({"l8_journey": {"gift": "returned"}}, ["l8_journey", "gift"], ["recovered", "returned"]) and not Places.step_done({"l8_journey": {"gift": "dropped"}}, ["l8_journey", "gift"], ["recovered", "returned"]), "value-list done check")
	if failures == 0:
		print("PASS atlas readable l8: explored-only walls, the way back at the arrival, Huline Temple after the walk to its door, far places hidden, temple-first marker clears on the visit, a full area shows %d places and %d exits" % [all_places, all_exits])
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
