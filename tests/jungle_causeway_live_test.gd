extends SceneTree
## Owner r12e report 5: the causeway west of (5529,-3715) must be gone after the exit ending. On the real Jungle host,
## each of the three endings (request_prop4398_event20 with its source predicate) queues g17352 through the staged
## prop4648 event20: 13 causeway floors sink (collision follows), the wall set swaps, controls 61/62 link and 84
## unlinks. Nothing collapses before an ending; movie end and skip leave the same world; quicksave/quickload keeps it;
## a save made before this host that already holds a played ending loads collapsed. Control84's native solid blocks a
## ray across its panel until the collapse unlinks it; regions 4429/4448/4447 refuse creatures (layer 11) afterwards,
## never the player.
const State = preload("res://scripts/lol2/jungle_exit_encounter_state.gd")
const FLAGS := {"shared": {"13": 0, "14": 1, "18": 1, "47": 0}, "locals": {"41": 0, "49": 0, "51": 0}}
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_causeway_live: ", message); quit(1)

func load_scene() -> void:
	if scene != null:
		scene.queue_free()
		await process_frame
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	scene.set_physics_process(false)
	scene.exit_encounter.set_physics_process(false)

const World = preload("res://tests/jungle_causeway_world.gd")
## Full live readout after two physics frames ("" when it matches standing/collapsed).
func world(collapsed: bool) -> String:
	await physics_frame
	await physics_frame
	return World.compare(scene, collapsed)

func run() -> void:
	await load_scene()
	if scene.causeway == null: return fail("Causeway host missing")
	var w: String = await world(false)
	if w != "": return fail("Initial " + w)
	# No premature collapse: the exit encounter runs (regions, supplied guard spawn, time) without an ending.
	var ctrl = scene.exit_encounter
	ctrl.spawn_guards()
	for i in 120: ctrl.advance(1.0 / 60.0)
	w = await world(false)
	if w != "": return fail("Collapsed before an ending: " + w)
	var cases := [[3, 0, "HW-BRDGE.VQA", "skip"], [0, 0, "E068E.VQA", "end"], [0, 1, "E069E.VQA", "skip"]]
	var path := "user://tests/jungle_causeway_live.json"
	DirAccess.make_dir_recursive_absolute("user://tests")
	for row in cases:
		await load_scene()
		ctrl = scene.exit_encounter
		ctrl.encounter.locals["48"] = row[0]
		ctrl.encounter.prop4398 = row[1]
		ctrl.request_prop4398_event20(FLAGS.duplicate(true))
		if str(ctrl.encounter.ending.get("movie", "")) != row[2] or not ctrl.active(): return fail("Ending %s did not start" % row[2])
		w = await world(true)
		if w != "": return fail("%s: during the movie %s" % [row[2], w])
		if row[3] == "skip": ctrl.skip_line()
		else: ctrl._advance_movie(10000.0)
		if ctrl.active(): return fail("%s movie did not finish" % row[2])
		w = await world(true)
		if w != "": return fail("%s: after movie %s %s" % [row[2], row[3], w])
		var once: int = ctrl.effect_log.filter(func(e): return str(e.type) == "group" and int(e.group) == 17352).size()
		if once != 1: return fail("%s queued g17352 %d times" % [row[2], once])
		if ctrl.effect_log.any(func(e): return str(e.type) == "unstaged_event"): return fail("Unstaged event20")
	# Save and restart keep the collapsed world.
	var error: String = scene.quicksave(path)
	if not error.is_empty(): return fail("Save: " + error)
	await load_scene()
	if (await world(false)) != "": return fail("Fresh scene not standing")
	error = scene.quickload(path)
	if not error.is_empty(): return fail("Load: " + error)
	w = await world(true)
	if w != "": return fail("Loaded " + w)
	# A save made before this host: no causeway entry, but its exit ending was played -> collapsed.
	var packet: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	packet.quests.erase("jungle_causeway")
	var legacy := "user://tests/jungle_causeway_legacy.json"
	var f := FileAccess.open(legacy, FileAccess.WRITE); f.store_string(JSON.stringify(packet)); f.close()
	await load_scene()
	error = scene.quickload(legacy)
	if not error.is_empty(): return fail("Legacy load: " + error)
	w = await world(true)
	if w != "" or scene.quest_state.has("jungle_causeway"): return fail("Legacy save %s (entry created: %s)" % [w, scene.quest_state.has("jungle_causeway")])
	# And without a played ending it stays standing.
	packet.quests.jungle_exit_encounter.encounter.ending = {}
	packet.quests.jungle_exit_encounter.movie = {"phase": "none", "elapsed": 0.0}
	f = FileAccess.open(legacy, FileAccess.WRITE); f.store_string(JSON.stringify(packet)); f.close()
	await load_scene()
	error = scene.quickload(legacy)
	if not error.is_empty(): return fail("Legacy (no ending) load: " + error)
	w = await world(false)
	if w != "": return fail("Legacy save without an ending " + w)
	print("PASS jungle_causeway_live: three endings (skip/end) sink the causeway once (4448/4435 -114 -> -200, 4445 -> -134), walls, controls 61/62/84 (84 solid), creature refusal 4429/4448/4447 and the eight props follow, player never refused; no early collapse; save/restart and legacy saves agree")
	quit(0)
