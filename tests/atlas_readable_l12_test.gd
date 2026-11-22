extends SceneTree
## Readable Atlas for the Claw Mountains (L12_CM), same rules as the Jungle (owner 2026-11-08). The player arrives from the
## Larkhon pass at the bottom of the icy gulch (the earned STORY-035 arrival save, native selector 1): M shows the way back and
## nothing of the far places; the earned gulch walk (tests/fixtures/l12_gulch_walk.json, the BJ05 main-chain route) explores
## more and still keeps Kenneth, Baccata and the citadel hidden; a full (old-save) area shows every place.
const Places := preload("res://scripts/lol2/atlas_places.gd")
const MyJournal := preload("res://scripts/lol2/my_journal.gd")
const Save := preload("res://scripts/lol2/act2_save.gd")
const AREA := "L12_CM"
const ARRIVAL := "res://tmp/l12_larkhon_arrival_earned_save.json"
var scene
var failures: int = 0

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

func open_atlas() -> void:
	scene.interface_hud.toggle_atlas()
	for i in 6: await process_frame

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL atlas readable l12: ", label)
	return ok

func report() -> Dictionary:
	return scene.interface_hud.atlas.readable_report()

func run() -> void:
	set_meta("lol2_map_start_selector", 1)
	scene = load("res://scenes/lol2/maps/L12_CM.tscn").instantiate()
	if "adapter_exit_seeds" in scene: scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not check(scene.get("ready_for_review"), "L12_CM ready"): quit(1); return
	var input: Dictionary = Save.read_save(ARRIVAL, "lol2-restoration-map-L12_CM")
	if not check(input.error.is_empty(), "earned Larkhon-pass arrival: " + str(input.error)): quit(1); return
	if not check(scene.apply_save(input.state).is_empty(), "apply the earned arrival"): quit(1); return
	# The STORY-035 save was written from a scene opened at the preview start (region 1948, the Baccata deck), so its explored
	# set names that region and not the gulch; a player arriving by the level change has only seen the gulch.
	scene.atlas_explored = preload("res://scripts/lol2/atlas_explored.gd").initial()
	scene.set_physics_process(false)
	for i in 10: await physics_frame
	var hud = scene.interface_hud
	await open_atlas()
	var r := report()
	check(bool(r.get("filtering", false)), "a new arrival filters the Atlas to explored regions")
	check(int(r.get("blocked", 0)) > 0, "the impassable regions are known to the Atlas (%d)" % int(r.get("blocked", 0)))
	# The player stands at the bottom of the icy gulch (native selector 1, region 735): the way back is the only thing known.
	check("icy_gulch" in r.get("exits", []), "the way back to the Darker Jungle shows at the arrival (exits %s)" % str(r.get("exits", [])))
	check(not ("baccata_l12" in r.get("places", []) or "kenneth" in r.get("places", []) or "citadel_gate" in r.get("exits", [])), "Kenneth, Baccata and the citadel stay hidden at the arrival (places %s, exits %s)" % [str(r.get("places", [])), str(r.get("exits", []))])
	check(r.get("plot", []).is_empty(), "no plot marker before a Journal note")
	check(hud.atlas.zoom > 1.0, "the Atlas opens fitted to the explored part (zoom %.1f)" % hud.atlas.zoom)
	var start_explored: int = int(r.get("explored", 0))
	var start_walls: int = int(r.get("walls", 0))
	hud.close_sheet()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l12_gulch_walk.json"))
	if not await walk(fixture.points): quit(1); return
	if not await walk(fixture.bridge): quit(1); return
	await open_atlas()
	var after := report()
	check(int(after.get("explored", 0)) > start_explored and int(after.get("walls", 0)) > start_walls, "the gulch walk explored more regions and drew more wall lines (%d -> %d regions, %d -> %d walls)" % [start_explored, int(after.get("explored", 0)), start_walls, int(after.get("walls", 0))])
	check("icy_gulch" in after.get("exits", []), "the way back stays on the Atlas after the climb")
	check(not ("baccata_l12" in after.get("places", []) or "kenneth" in after.get("places", []) or "ice_tunnel" in after.get("places", []) or "citadel_gate" in after.get("exits", [])), "the far places stay hidden after the climb (places %s, exits %s)" % [str(after.get("places", [])), str(after.get("exits", []))])
	var note := ""
	if note != "":
		MyJournal.discover(scene, note)
		for i in 4: await process_frame
		check(note in report().get("plot", []), "the Journal note puts a plot marker at its place")
		var row: Dictionary = {}
		for candidate in Places.plot(AREA):
			if str(candidate.note) == note: row = candidate
		var done_path: Array = row.get("done", [])
		var node: Dictionary = scene.quest_state
		for i in done_path.size() - 1:
			var key: String = str(done_path[i])
			if not node.has(key) or not node[key] is Dictionary: node[key] = {}
			node = node[key]
		node[str(done_path[done_path.size() - 1])] = true
		for i in 4: await process_frame
		check(not (note in report().get("plot", [])), "the marker clears once the quest field is set")
	scene.atlas_explored = {"version": 1, "areas": {AREA: {"full": true, "regions": []}}}
	for i in 4: await process_frame
	var full := report()
	var all_places := 0
	var all_exits := 0
	for row in Places.places(AREA):
		if str(row.get("kind", "place")) == "exit": all_exits += 1
		else: all_places += 1
	check(full.get("places", []).size() == all_places and full.get("exits", []).size() == all_exits, "a full area shows every place (%d of %d) and exit (%d of %d)" % [full.get("places", []).size(), all_places, full.get("exits", []).size(), all_exits])
	if failures == 0:
		print("PASS atlas readable l12: explored-only at the earned arrival, the way back shows, Kenneth/Baccata/citadel hidden before and after the gulch climb, a full area shows %d places and %d exits" % [all_places, all_exits])
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
