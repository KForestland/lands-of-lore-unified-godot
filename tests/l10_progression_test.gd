extends SceneTree
## L10_DC progression through the native script host (act2_progression.gd on act2_map.gd): the two level changes
## (region 0 -> level 8 arrival 2, region 42 -> level 9 arrival 3 behind predicate 63 on local 11), the region-3 hop,
## the rotary doors 87/88 on hinges with their kind-4 use, and what each step runs on (PROVEN / adapters / blocked).
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func verdicts(results: Array) -> Array:
	var out := []
	for r in results: out.append("%d:%s%s" % [int(r.group), str(r.status), "" if r.get("adapters", []).is_empty() else "+A"])
	return out
func run() -> void:
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
	root.add_child(scene)
	for i in 5: await process_frame
	var p = scene.progression
	check(p != null and p.native != null and p.area_id == "L10_DC", "the binder is attached with the L10 scripts loaded")
	if p == null or p.native == null: quit(1); return
	p.change_scene_enabled = false
	check(p.regions.size() == 4320 and p.scripted_movables == [87, 88, 89] and p.hinges.size() == 20, "4320 nav regions; scripted movables 87/88 (rotary, on hinges) and 89 (%s, %d hinges)" % [p.scripted_movables, p.hinges.size()])
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
	var expected_excluded: Dictionary = p.hinge_faces("L10_DC", geometry)
	# astra 029b7ae/c981337: tomb doors (l10_tomb_state.gd doors()) and assembly 70 are drawn by their owners, not the static mesh.
	var tomb_doors: Array = preload("res://scripts/lol2/l10_tomb_state.gd").doors()
	for i in geometry.faces.size():
		var face: Dictionary = geometry.faces[i]
		if preload("res://scripts/lol2/l10_oil.gd").owns(face) or preload("res://scripts/lol2/l10_emperor_entry.gd").entry_owns(face) or preload("res://scripts/lol2/l10_emperor.gd").owns(face):expected_excluded[i]=true
		if face.get("placement_kind") == "static_assembly" and (int(face.get("source_index",-1)) in [61,70,165,166,167,168,169,170,171,172,173] or int(face.get("source_index",-1)) in tomb_doors): expected_excluded[i] = true
	check(scene.excluded_faces == expected_excluded, "all source mover + tomb-door faces left the static mesh (%d vs %d)" % [scene.excluded_faces.size(), expected_excluded.size()])
	# Arrival 2 (-542, 856) is region 65; the player's region is tracked from the nav quads.
	check(p.region_at(Vector3(-542, 32, -856)) == 65, "arrival 2 lies in region 65 (%d)" % p.region_at(Vector3(-542, 32, -856)))
	# Level change 1: region 0's kind-12 event, group 0 = opcode 2 arm 0x1C (PROVEN with global 0x223D6 = 0) -> level 8, arrival 2.
	var results: Array = p.enter_region(0)
	check(verdicts(results) == ["0:ran"] and p.level_changes.size() == 1 and int(p.level_changes[0].level) == 8 and int(p.level_changes[0].selector) == 2 and str(p.level_changes[0].scene).ends_with("darker_jungle.tscn"), "region 0 -> level change to level 8 arrival 2 (the Savage Jungle), PROVEN (%s %s)" % [verdicts(results), p.level_changes])
	# The hop region 3 (group 90: opcode 7 indexes 7 and 0 on control 65) runs on the adapter opcode7_control_records (backlog 4
	# item 9 LIKELY): bits 2 and 1 ORed into byte +3 of control 65's matching records; what those records drive is not hosted.
	results = p.enter_region(3)
	check(verdicts(results) == ["90:ran+A"] and results[0].adapters.has("opcode7_control_records") and p.native.field("control:65:records", "bit_0x03_0x04") == 1 and p.native.field("control:65:records", "bit_0x03_0x02") == 1, "region 3's group 90 runs on opcode7_control_records: bits 2 and 1 of control 65's record byte +3 (%s)" % [verdicts(results)])
	# Level change 2: region 42 behind predicate 63 (local 11 == 1): rejected until local 11 is 1, then level 9 arrival 3.
	results = p.enter_region(42)
	check(verdicts(results) == ["108:unhosted"] and str(results[0].reasons[0]).contains("local 11") and p.level_changes.size() == 1, "region 42 is unhosted while local 11 is not known (predicate 63 reads it) (%s)" % [verdicts(results)])
	p.native.set_local(11, 2)
	p.current_region = -1
	results = p.enter_region(42)
	check(verdicts(results) == ["108:rejected"] and p.level_changes.size() == 1, "with local 11 = 2 (what group 24 stores) region 42 is rejected by predicate 63")
	# The native writer of local 11 = 1: control 150's kind-6 record (caller byte 9) -> group 19732 = opcode 197 arm 10 on 65
	# (adapter opcode197_list_mark), two opcode-9 0x15 enqueues (controls 114/113 -> groups 19070/19052) and opcode 198
	# local 11 = 1. What fires that kind-6 event natively (caller byte 9) is not traced; the test fires it.
	results = p.use_exit("control:150")
	check(verdicts(results) == ["19732:ran+A"] and results[0].adapters.has("opcode197_list_mark") and int(p.native.locals.get(11, -1)) == 1, "control 150's kind-6 event runs group 19732 (opcode 197 hosted) and writes local 11 = 1 natively (%s %s)" % [verdicts(results), results[0].reasons if not results.is_empty() else []])
	check(p.native.enqueued_results.size() == 2 and p.native_log.filter(func(e): return str(e.type) == "enqueue").size() == 2, "group 19732's two enqueues fired controls 114 and 113 (kind 6, caller byte 0x14)")
	p.current_region = -1
	results = p.enter_region(42)
	check(verdicts(results) == ["108:ran"] and p.level_changes.size() == 2 and int(p.level_changes[1].level) == 9 and int(p.level_changes[1].selector) == 3, "with local 11 = 1 region 42 -> level 9 arrival 3 (the Dracoid Ruins teleport), PROVEN")
	# Doors 87/88: E fires kind 4 (arg_c 0, context = the door); the groups that run turn the hinge by the travel word.
	results = p.use(87)
	var door_rows := verdicts(results)
	var ran := 0
	for r in results: if str(r.status) == "ran": ran += 1
	check(not results.is_empty(), "door 87's kind-4 use fires its groups (%s)" % [door_rows])
	var reasons := []
	for r in results: if str(r.status) == "unhosted": reasons.append(str(r.reasons[0]).get_slice(": ", 1).left(60))
	print("door 87 verdicts: %s; blocked by: %s; travel %s" % [door_rows, reasons, p.travel.get(87, -1)])
	check(p.route_log.size() == 7 and p.native_log.filter(func(e): return str(e.type) == "global").size() == 4, "route log holds the seven fired events; the two level changes committed four globals (%d)" % p.route_log.size())
	# An arrival override: the next L10 scene started at selector 1 stands at (-150, 221) region 5 with heading 1.
	set_meta("lol2_map_start_selector", 1)
	scene.queue_free(); await process_frame
	var again = load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
	root.add_child(again)
	for i in 5: await process_frame
	check(again.player.position == Vector3(-150, 32, -221) and again.start_selector == 1 and not has_meta("lol2_map_start_selector"), "meta lol2_map_start_selector moves the start to arrival 1 (%s)" % again.player.position)
	again.queue_free(); await process_frame
	print("L10 progression: %d failures" % failures)
	if failures == 0: print("PASS l10 progression: region 0 -> L8 arrival 2 and region 42 -> L9 arrival 3 (behind local 11, written by group 19732 through opcode 197) run on the host, region 3 blocked by opcode 7, doors 87/88 on hinges with kind-4 use fired, arrival override honoured")
	quit(0 if failures == 0 else 1)
