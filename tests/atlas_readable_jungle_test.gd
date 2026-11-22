extends SceneTree
## Owner 2026-11-08 (AI_COMMS/ATLAS_READABLE_20261108.md): the Atlas must be understandable, with edges, named places and plot
## points, explored-only. Earned walk: a new game's Jungle arrival (353, -4909), M opens the Atlas; then the walk to the
## clearing outside the village gate (tests/fixtures/atlas_jungle_start_walk.json, blocker-avoiding source graph), M again.
## Checks: wall lines are drawn only for explored regions; "Road from the Museum" shows at the start and "Huline Village"
## only after the walk; far places (Armorer's Glen, Monastery, Hive Caves) stay hidden; a discovered Journal note puts a
## plot marker at the Hive and the marker clears when the gate admission flag is set; an old save (area full) shows all.
const Places := preload("res://scripts/lol2/atlas_places.gd")
const MyJournal := preload("res://scripts/lol2/my_journal.gd")
var scene
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL atlas readable: ", label)
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
		if not check(reached, "walk stuck before point %d %s at %s" % [i, str(points[i]), scene.player.global_position]): return false
	return true

func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not check(scene.get("ready_for_review"), "Jungle ready"): quit(1); return
	scene.set_physics_process(false)
	for i in 10: await physics_frame
	await open_atlas()
	var first := report()
	check(bool(first.get("filtering", false)), "a new game filters the Atlas to explored regions")
	# The arrival region's four sides are all linked (creature_nav 3875), so the first wall lines come with the walk.
	check(int(first.get("explored", 0)) >= 1, "the arrival region is explored")
	check(scene.interface_hud.atlas.zoom > 1.0, "the Atlas opens fitted to the explored part (zoom %.1f)" % scene.interface_hud.atlas.zoom)
	check("museum_road" in first.get("exits", []), "the way back to the Museum shows at the arrival")
	check(not ("village_gate" in first.get("places", [])), "the village is not shown before it is explored")
	check(not ("hive" in first.get("exits", [])) and not ("armorer" in first.get("places", [])), "far places stay hidden at the start")
	check(first.get("plot", []).is_empty(), "no plot marker before a Journal note")
	check(int(first.get("blocked", 0)) > 0, "the Jungle's impassable thicket regions are known to the Atlas (%d)" % int(first.get("blocked", 0)))
	var start_walls: int = int(first.get("walls", 0))
	var start_explored: int = int(first.get("explored", 0))
	scene.interface_hud.close_sheet()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/atlas_jungle_start_walk.json"))
	if not await walk(fixture.points): quit(1); return
	await open_atlas()
	var after := report()
	check(int(after.get("explored", 0)) > start_explored and int(after.get("walls", 0)) > start_walls, "the walk explored more regions and drew more wall lines (%d -> %d regions, %d -> %d walls)" % [start_explored, int(after.get("explored", 0)), start_walls, int(after.get("walls", 0))])
	check("village_gate" in after.get("places", []), "Huline Village shows after walking to its gate")
	check(not ("armorer" in after.get("places", [])) and not ("monastery" in after.get("places", [])) and not ("hive" in after.get("exits", [])), "Armorer's Glen, Monastery and the Hive stay hidden")
	# Luther hears from the elder that the village is closed while Shalla's people are in the Hive: the note marks the Hive.
	MyJournal.discover(scene, "gate_closed_before_shalla")
	for i in 4: await process_frame
	var noted := report()
	check("gate_closed_before_shalla" in noted.get("plot", []), "the gate note puts a plot marker at the Hive")
	scene.quest_state.jungle_village.local24 = 1
	for i in 4: await process_frame
	check(not ("gate_closed_before_shalla" in report().get("plot", [])), "the marker clears once the gate admits Luther")
	# An older save carries the area as fully explored: every place and exit shows.
	scene.atlas_explored = {"version": 1, "areas": {"L4_HJ": {"full": true, "regions": []}}}
	for i in 4: await process_frame
	var full := report()
	var all_places := 0
	var all_exits := 0
	for row in Places.places("L4_HJ"):
		if str(row.get("kind", "place")) == "exit": all_exits += 1
		else: all_places += 1
	check(full.get("places", []).size() == all_places and full.get("exits", []).size() == all_exits, "a full area shows every place (%d) and exit (%d)" % [full.get("places", []).size(), full.get("exits", []).size()])
	check(Places.step_done({"a": {"b": 1}}, ["a", "b"]) and not Places.step_done({"a": {"b": 0}}, ["a", "b"]) and not Places.step_done({}, []), "quest path checks")
	if failures == 0:
		print("PASS atlas readable jungle: explored-only walls, Road from the Museum at the arrival, Huline Village after the gate walk, far places hidden, Hive plot marker from the gate note clears on admission, a full area shows %d places and %d exits" % [all_places, all_exits])
	quit(0 if failures == 0 else 1)
