extends SceneTree
## Readable Atlas for the Citadel of the Ruloi (L13_RC), same rules as the Jungle (owner 2026-11-08). No earned walk fixture exists for this
## level yet (Grok BJ01 brings the L8 -> L12 route), so this checks the native start: M shows the nearby way out, far places stay
## hidden, a discovered Journal note marks its place and clears on the quest field, and a full (old-save) area shows every place.
const Places := preload("res://scripts/lol2/atlas_places.gd")
const MyJournal := preload("res://scripts/lol2/my_journal.gd")
const AREA := "L13_RC"
var scene
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL atlas readable l13: ", label)
	return ok

func report() -> Dictionary:
	return scene.interface_hud.atlas.readable_report()

func run() -> void:
	scene = load("res://scenes/lol2/maps/L13_RC.tscn").instantiate()
	if "adapter_exit_seeds" in scene: scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not check(scene.get("ready_for_review"), "L13_RC ready"): quit(1); return
	scene.set_physics_process(false)
	for i in 10: await physics_frame
	var hud = scene.interface_hud
	hud.toggle_atlas()
	for i in 6: await process_frame
	var r := report()
	check(bool(r.get("filtering", false)), "a new arrival filters the Atlas to explored regions")
	check(int(r.get("blocked", 0)) > 0, "the impassable regions are known to the Atlas (%d)" % int(r.get("blocked", 0)))
	check("citadel_exit" in r.get("exits", []), "the way out beside the arrival shows (exits %s)" % str(r.get("exits", [])))
	check(not ("dawn_prison" in r.get("places", []) or "altar" in r.get("places", [])), "far places stay hidden (places %s, exits %s)" % [str(r.get("places", [])), str(r.get("exits", []))])
	check(r.get("plot", []).is_empty(), "no plot marker before a Journal note")
	check(hud.atlas.zoom > 1.0, "the Atlas opens fitted to the explored part (zoom %.1f)" % hud.atlas.zoom)
	var note := "l13_dreamstone"
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
		print("PASS atlas readable l13: explored-only at the arrival, the way out shows, far places hidden, Journal marker clears, a full area shows %d places and %d exits" % [all_places, all_exits])
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
