extends SceneTree
## L13_RC, L16_CA and L19_BC through act2_progression.gd: every opcode-2 level change decodes to the level and arrival the
## exports' exit labels name (byte 5 = selector << 5 | level), the region or control event that owns it runs PROVEN on the
## host (or waits on its predicate), and the rotary scripted movables stand on hinges.
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func verdicts(results: Array) -> Array:
	var out := []
	for r in results: out.append("%d:%s%s" % [int(r.group), str(r.status), "" if r.get("adapters", []).is_empty() else "+A"])
	return out
func open_map(area: String) -> Node:
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/maps/%s.tscn" % area).instantiate()
	scene.adapter_exit_seeds = false # This test exercises the unresolved native/preview gates.
	root.add_child(scene)
	return scene
func run() -> void:
	# L13_RC: region 489 -> level 12 (Claw Mountains, L12_CM) arrival 2; no usable movable.
	var scene = open_map("L13_RC")
	for i in 5: await process_frame
	var p = scene.progression
	# L13Altar owns movables 50-68, so the progression hinge set is the other 16 opcode-1 movers.
	check(p != null and p.native != null and p.scripted_movables.is_empty() and p.hinges.size() == 16, "L13: binder attached, no kind-4 use owners; 16 opcode-1 movers")
	p.change_scene_enabled = false
	var r: Array = p.enter_region(489)
	check(verdicts(r) == ["706:ran"] and p.level_changes.size() == 1 and int(p.level_changes[0].level) == 12 and int(p.level_changes[0].selector) == 2, "L13: region 489 -> level 12 arrival 2 (Claw Mountains), PROVEN (%s)" % [verdicts(r)])
	scene.queue_free(); await process_frame
	# L16_CA: region 9822 -> level 17 (Hive Caverns, L17_HC) arrival 3; control 74's kind-5 event value 4 -> level 17 arrival 1.
	scene = open_map("L16_CA")
	for i in 5: await process_frame
	p = scene.progression
	p.change_scene_enabled = false
	assert(FileAccess.get_sha256("res://tests/fixtures/g03_l16_hinge_membership.json")=="e410e389d40de25d8903bc2b4376af629a668b7f9c1089742743a3e54773a76b","Independent source-census fixture pin")
	var membership:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/g03_l16_hinge_membership.json"))
	for source in membership.sources:
		assert(FileAccess.get_sha256("res://"+str(source))==membership.sources[source],"Pinned source-only L16 membership census")
	var expected_ids:Array=membership.original_hinge_ids+membership.additional_hinge_ids;expected_ids.sort()
	var actual_ids:Array=p.hinges.keys();actual_ids.sort()
	check(p != null and p.scripted_movables.size()==56 and PackedInt32Array(actual_ids)==PackedInt32Array(expected_ids),"L16: 56 kind4, all original103 hinges plus exact11 published G03 movers; no owner lost (%d/%d)"%[p.scripted_movables.size(),p.hinges.size()])
	r = p.enter_region(9822)
	check(verdicts(r) == ["7268:ran"] and p.level_changes.size() == 1 and int(p.level_changes[0].level) == 17 and int(p.level_changes[0].selector) == 3, "L16: region 9822 -> level 17 arrival 3 (Hive Caverns), PROVEN (%s)" % [verdicts(r)])
	r = p.fire("control:74", 5, {"caller_byte": 4, "caller_byte_2": 0, "context": "control:74"})
	var ran_42056 := false
	for x in r: if int(x.group) == 42056 and str(x.status) == "ran": ran_42056 = true
	check(ran_42056 and p.level_changes.size() == 2 and int(p.level_changes[1].level) == 17 and int(p.level_changes[1].selector) == 1, "L16: control 74 kind-5 value 4 -> level 17 arrival 1, PROVEN (%s %s)" % [verdicts(r), r[0].reasons if not r.is_empty() else []])
	scene.queue_free(); await process_frame
	# L19_BC: region 22 -> level 17 arrival 2; region 2369 -> level 20 (Birthing / Summoning Chamber, L20_BB) arrival 1 or 2
	# behind predicates 204/205 on [0x26E58 + 52] (0 or 1).
	scene = open_map("L19_BC")
	for i in 5: await process_frame
	p = scene.progression
	p.change_scene_enabled = false
	check(p != null and p.scripted_movables.size() == 23 and p.hinges.size() == 28, "L19: 23 kind-4 movables, 28 source movers (%d/%d)" % [p.scripted_movables.size(), p.hinges.size()])
	r = p.enter_region(22)
	check(verdicts(r) == ["0:ran"] and p.level_changes.size() == 1 and int(p.level_changes[0].level) == 17 and int(p.level_changes[0].selector) == 2, "L19: region 22 -> level 17 arrival 2 (Hive Caverns), PROVEN (%s)" % [verdicts(r)])
	# The L19 preview seed is retired. A fresh start leaves [0x26E58 + 52] unknown, so both exits stay unresolved.
	check(p.seeds_applied.is_empty() and not scene.arrived_by_level_change, "L19: a fresh start leaves [0x26E58 + 52] unknown (%s)" % [p.seeds_applied])
	r = p.enter_region(2369)
	# Adapter L19_to_L20_history (lead 2026-11-14, DEVIATIONS 0661): at the door an unknown cell comes from the player's own
	# L20 history - no curse cast into the mother here, so 0 -> arrival 1.
	var hist: Array = p.seeds_applied.filter(func(x): return str(x.get("adapter", "")) == "L19_to_L20_history")
	check(verdicts(r) == ["15784:ran", "15790:rejected"] and p.level_changes.size() == 2 and int(p.level_changes[1].selector) == 1 and hist.size() == 1 and int(hist[0].value) == 0, "L19: region 2369 with [0x26E58 + 52] unknown takes it from the L20 history (0) -> arrival 1 (%s %s)" % [verdicts(r), p.seeds_applied])
	p.native.set_local_e58(52, 0)
	p.current_region = -1
	r = p.enter_region(2369)
	check(verdicts(r) == ["15784:ran", "15790:rejected"] and p.level_changes.size() == 3 and int(p.level_changes[2].level) == 20 and int(p.level_changes[2].selector) == 1, "L19: with [0x26E58 + 52] = 0 -> level 20 arrival 1 (Birthing Chamber), 205 rejected (%s)" % [verdicts(r)])
	p.native.set_local_e58(52, 1)
	p.current_region = -1
	r = p.enter_region(2369)
	check(verdicts(r) == ["15784:rejected", "15790:ran"] and p.level_changes.size() == 4 and int(p.level_changes[3].level) == 20 and int(p.level_changes[3].selector) == 2, "L19: with [0x26E58 + 52] = 1 -> level 20 arrival 2 (Summoning Chamber) (%s)" % [verdicts(r)])
	scene.queue_free(); await process_frame
	# Entered by a native level change (meta lol2_level_change, as _change_level sets it): no seed, the gate stays open in Classic.
	set_meta("lol2_level_change", true)
	set_meta("lol2_map_start_selector", 2)
	scene = open_map("L19_BC")
	for i in 5: await process_frame
	p = scene.progression
	p.change_scene_enabled = false
	check(scene.arrived_by_level_change and not has_meta("lol2_level_change") and p.seeds_applied.is_empty(), "L19 entered by a level change: no seed applied (%s)" % [p.seeds_applied])
	r = p.enter_region(2369)
	check(verdicts(r) == ["15784:ran", "15790:rejected"], "L19 by level change: region 2369 with the cell unknown takes it from the L20 history (0) -> arrival 1 (%s %s)" % [verdicts(r), p.seeds_applied])
	scene.queue_free(); await process_frame
	print("Act 2 progression levels: %d failures" % failures)
	if failures == 0: print("PASS act2 progression levels: L13 -> L12/2, L16 -> L17/3 and L17/1 (control 74), L19 -> L17/2 and L20/1|2 behind predicates 204/205; every level change PROVEN on the host; all source opcode-1 geometry owned dynamically")
	quit(0 if failures == 0 else 1)
