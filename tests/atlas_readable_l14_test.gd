extends SceneTree
## Readable Atlas for the Huline Temple (L14_HT), same rules as the Jungle (owner 2026-11-08). The player arrives from the
## Savage Jungle temple door with the Dreamstone (the earned STORY-049 arrival save, native selector 1): M shows the way back and
## nothing of the rooms beyond; the entry walk (tests/fixtures/l14_entry_walk.json, the BJ08 chain's first stretch) shows the
## ritual chamber and keeps the far places hidden; the chalice Journal note marks the Chamber of Voices and clears on the offer;
## a full (old-save) area shows every place.
const Places := preload("res://scripts/lol2/atlas_places.gd")
const MyJournal := preload("res://scripts/lol2/my_journal.gd")
const Save := preload("res://scripts/lol2/act2_save.gd")
const AREA := "L14_HT"
const ARRIVAL := "res://tmp/l14_temple_arrival_qualified_save.json"
var scene
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		print("FAIL atlas readable l14: ", label)
	return ok

func report() -> Dictionary:
	return scene.interface_hud.atlas.readable_report()

func walk(points: Array) -> bool:
	for i in points.size():
		var to := Vector2(float(points[i][0]), float(points[i][1]))
		var reached := false
		var prior: Vector3 = scene.player.global_position
		var stalled := 0
		for f in 900:
			var off := to - Vector2(scene.player.global_position.x, scene.player.global_position.z)
			if off.length() < 6.0:
				reached = true
				break
			# The temple entry has a stair lip the body cannot step up; the earned walks hop it the same way (BJ08 finding).
			if scene.player.global_position.distance_to(prior) < 0.05: stalled += 1
			else: stalled = 0
			prior = scene.player.global_position
			if stalled == 20 and scene.player.is_on_floor(): scene.request_jump(); stalled = 0
			scene.move_grounded(Vector3(off.x, 0.0, off.y).normalized(), 1.0 / 60.0)
			await physics_frame
		if not reached:
			var hits := ""
			for j in scene.player.get_slide_collision_count():
				var c: KinematicCollision3D = scene.player.get_slide_collision(j)
				hits += " %s %s" % [c.get_collider().get_path(), c.get_normal()]
			print("WALK HITS", hits)
		if not check(reached, "walk stuck before point %d %s at %s" % [i, str(points[i]), scene.player.global_position]): return false
	return true

func open_atlas() -> void:
	scene.interface_hud.toggle_atlas()
	for i in 6: await process_frame

func run() -> void:
	set_meta("lol2_map_start_selector", 1)
	scene = load("res://scenes/lol2/maps/L14_HT.tscn").instantiate()
	if "adapter_exit_seeds" in scene: scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not check(scene.get("ready_for_review"), "L14_HT ready"): quit(1); return
	var input: Dictionary = Save.read_save(ARRIVAL, "lol2-restoration-map-L14_HT")
	if not check(input.error.is_empty(), "earned temple arrival: " + str(input.error)): quit(1); return
	if not check(scene.apply_save(input.state).is_empty(), "apply the earned arrival"): quit(1); return
	# The hosts restore their receipts (the main doors open) in physics; give them frames before the walk takes over the body.
	for i in 10: await physics_frame
	scene.atlas_explored = preload("res://scripts/lol2/atlas_explored.gd").initial()
	scene.player.set_physics_process(false)
	scene.set_physics_process(false)
	for i in 10: await physics_frame
	var hud = scene.interface_hud
	await open_atlas()
	var r := report()
	check(bool(r.get("filtering", false)), "a new arrival filters the Atlas to explored regions")
	check("temple_exit" in r.get("exits", []), "the way back to the Savage Jungle shows at the arrival (exits %s)" % str(r.get("exits", [])))
	check(not ("chamber_of_voices" in r.get("exits", []) or "grinder" in r.get("places", []) or "spiral_stair" in r.get("places", [])), "the rooms beyond stay hidden at the arrival (places %s, exits %s)" % [str(r.get("places", [])), str(r.get("exits", []))])
	check(r.get("plot", []).is_empty(), "no plot marker before a Journal note")
	var start_explored: int = int(r.get("explored", 0))
	hud.close_sheet()
	var entry: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l14_entry_walk.json"))
	if not await walk(entry): quit(1); return
	await open_atlas()
	var after := report()
	check(int(after.get("explored", 0)) > start_explored, "the entry walk explored more regions (%d -> %d)" % [start_explored, int(after.get("explored", 0))])
	check("ritual_chamber" in after.get("places", []), "the ritual chamber shows once entered (places %s)" % str(after.get("places", [])))
	check(not ("chamber_of_voices" in after.get("exits", []) or "faux_belial" in after.get("places", []) or "spiral_stair" in after.get("places", [])), "the far rooms stay hidden after the entry (places %s, exits %s)" % [str(after.get("places", [])), str(after.get("exits", []))])
	MyJournal.discover(scene, "l14_chalice")
	for i in 4: await process_frame
	check("l14_chalice" in report().get("plot", []), "the chalice note puts a plot marker at the Chamber of Voices")
	scene.quest_state["l14_chamber_voices"] = {"version": 1, "offered": true}
	for i in 4: await process_frame
	check(not ("l14_chalice" in report().get("plot", [])), "the marker clears once the Dreamstone is offered")
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
		print("PASS atlas readable l14: explored-only at the earned arrival, the way back shows, the ritual chamber after the entry walk, far rooms hidden, chalice marker clears on the offer, a full area shows %d places and %d exits" % [all_places, all_exits])
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
