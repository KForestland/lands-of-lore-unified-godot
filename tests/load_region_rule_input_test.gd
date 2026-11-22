extends SceneTree
## Load rule, real input (lead 2026-11-14; scripts/lol2/load_region_rule.gd). F5 standing in a region whose entry group
## presses a lever (opcode 9 enqueue), then F9: the load must not run that entry again; it re-arms only the repeat-safe
## commands. Two levels of different kind (the L19 cab ride is l19_cab_ride_save_test):
##  (a) L10 region 247 (the yard; entry group 126 enqueues actor 67, which changes its mode);
##  (b) L14 region 2546 (by the crawl tunnel; entry group 2402 enqueues object 68).
## Red (before the rule): after F9 the progression logs the region's entry (event 2) and the enqueue fires again.
## Green: no entry event after F9, no enqueue; the log shows the load re-arm row instead.
## Test aids: the F2 start of the level and the stand inside the region (placed, then left to settle and enter it).
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
func _initialize() -> void: run.call_deferred()
func fail(m: String) -> void:
	printerr("FAIL load region rule input: ", m)
	quit(1)
func tap(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new(); e.keycode = code; e.physical_keycode = code; e.pressed = down
		Input.parse_input_event(e); Input.flush_buffered_events()
		await process_frame
func open_start(id: String) -> Node:
	var entry := {}
	for c in Starts.manifest().entries:
		if str(c.id) == id: entry = c
	var old := current_scene
	var err: String = load("res://scripts/lol2/game_save.gd").resume_checkpoint(self, entry.area_id, Starts.read(entry).state, true)
	if not err.is_empty(): fail(id + ": " + err); return null
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene != old and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	for i in 30: await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return current_scene
func case(id: String, region: int, at: Vector3, label: String) -> bool:
	var scene: Node = await open_start(id)
	if scene == null: return false
	var creatures = scene.get("act2_creatures")
	if creatures is Node: creatures.process_mode = Node.PROCESS_MODE_DISABLED
	scene.player.global_position = at; scene.player.velocity = Vector3.ZERO
	for i in 60: await physics_frame
	var prog: Node = scene.progression
	if int(prog.current_region) != region: fail("%s: the stand is in region %d, not %d" % [label, int(prog.current_region), region]); return false
	var entered: Array = prog.route_log.filter(func(r): return str(r.get("object")) == "region:%d" % region and str(r.get("event")) == "2")
	if entered.is_empty(): fail("%s: walking in did not run region %d's entry (no red possible)" % [label, region]); return false
	await tap(KEY_F5)
	for i in 20: await physics_frame
	var old := current_scene
	await tap(KEY_F9)
	for i in 1500:
		await process_frame
		if is_instance_valid(current_scene) and current_scene != old and current_scene.get("player") is Node3D and current_scene.is_node_ready(): break
	scene = current_scene
	if scene == old: fail("%s: F9 did not reload" % label); return false
	prog = scene.progression
	var enqueued: Array = []
	prog.native.connect("event_enqueued", func(ref: String, kind: int, caller: int): enqueued.append("%s/%d/%d" % [ref, kind, caller]))
	var c2 = scene.get("act2_creatures")
	if c2 is Node: c2.process_mode = Node.PROCESS_MODE_DISABLED
	for i in 30: await physics_frame
	var again: Array = prog.route_log.filter(func(r): return str(r.get("object")) == "region:%d" % region and str(r.get("event")) == "2")
	var rearm: Array = prog.load_rearm_log.filter(func(r): return str(r.get("object")) == "region:%d" % region and str(r.get("event")) == "load_rearm")
	print("RULE %s: after F9 region %d entry runs %d, enqueues %s, re-arm %s, current region %d" % [label, region, again.size(), str(enqueued), str(rearm), int(prog.current_region)])
	if not again.is_empty(): fail("%s: F9 ran region %d's entry again (%s)" % [label, region, str(again)]); return false
	if not enqueued.is_empty(): fail("%s: F9 enqueued %s again" % [label, str(enqueued)]); return false
	if rearm.size() != 1 or int(prog.current_region) != region: fail("%s: no load re-arm row for region %d (%s)" % [label, region, str(rearm)]); return false
	return true
func run() -> void:
	set_meta("original_game_verified", true)
	if not await case("act2-l10", 247, Vector3(1802, 0 + 32.5, -1137), "(a) L10 yard 247"): return
	if not await case("act2-l14", 2546, Vector3(1023, 0 + 32.5, -5464), "(b) L14 2546"): return
	print("PASS load region rule input: F5/F9 in L10 247 and L14 2546 runs no entry again (no lever press); the load re-arms instead")
	quit(0)
