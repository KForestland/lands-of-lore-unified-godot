extends SceneTree
## Grok backlog-2 item 2 (opcode 197, PROVEN): the bit stores of arms 0-5/8/9 on the [0x22D0C] record named by the command
## word, the adapters for arms 6/7 (unloaded word +0x18) and 10 (unheld [0x2B53C] table), no store above arm 10, refusals
## with the adapters off, and the real groups: L13 9360 (arm 2) and L1 12556 (arm 5), PROVEN, L13 1864 (arm 10), L16 49070 (arm 7),
## L10 11480 / L19 918 (blocked by later opcodes, no longer by 197), and L10 19732, which now runs as a whole and writes local 11 = 1 (the Dracoid Ruins teleport gate).
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func cmd(arm: int, word: int = 65) -> Dictionary:
	var b := PackedByteArray([197, 0x90, word & 0xFF, (word >> 8) & 0xFF, arm, 0])
	return {"opcode": 197, "kind": 0x90, "target": word, "file_offset": -1, "bytes": b, "raw_hex": b.hex_encode()}
func run() -> void:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L10_DC.json").is_empty(), "L10_DC loads")
	var changes: Array = []
	host.object_state_changed.connect(func(ref: String, field: String, value: int): changes.append([ref, field, value]))
	var g := 970000
	for arm in range(0, 12):
		host.groups[host.group_key(1, g + arm)] = [cmd(arm)]
	var rec := "0x22d0c:65"
	var r: Dictionary = host.execute_group(1, 970000)
	check(str(r.status) == "ran" and r.adapters.is_empty() and changes == [[rec, "bit_0x1c_0x01", 0]], "arm 0 clears bit 0 of byte +0x1C of record 65, PROVEN, no adapter (%s)" % [changes])
	changes.clear(); r = host.execute_group(1, 970001)
	check(str(r.status) == "ran" and changes == [[rec, "bit_0x1c_0x02", 0]], "arm 1 clears bit 1")
	changes.clear(); r = host.execute_group(1, 970002)
	check(str(r.status) == "ran" and changes == [[rec, "bit_0x1c_0x01", 1]], "arm 2 sets bit 0")
	changes.clear(); r = host.execute_group(1, 970003)
	check(str(r.status) == "ran" and changes == [[rec, "bit_0x1c_0x02", 1]], "arm 3 sets bit 1")
	changes.clear(); r = host.execute_group(1, 970005)
	check(str(r.status) == "ran" and changes == [[rec, "bit_0x1c_0x01", 0], [rec, "bit_0x1c_0x02", 0]], "arm 5 clears bits 0 and 1 (%s)" % [changes])
	changes.clear(); r = host.execute_group(1, 970004)
	check(str(r.status) == "ran" and changes == [[rec, "bit_0x1c_0x01", 1], [rec, "bit_0x1c_0x02", 1]], "arm 4 sets bits 0 and 1")
	changes.clear(); r = host.execute_group(1, 970008)
	check(str(r.status) == "ran" and changes == [[rec, "bit_0x1d_0x01", 1]], "arm 8 sets bit 0 of byte +0x1D")
	changes.clear(); r = host.execute_group(1, 970009)
	check(str(r.status) == "ran" and changes == [[rec, "bit_0x1d_0x01", 0]], "arm 9 clears bit 0 of byte +0x1D")
	changes.clear(); r = host.execute_group(1, 970006)
	check(str(r.status) == "ran" and r.adapters == ["opcode197_region_record"] and changes == [["0x22d10:region:65", "bit_0x19_0x04", 0]], "arm 6 clears bit 2 of byte +0x19 of the region's 42-byte record on the adapter (%s %s)" % [r.adapters, changes])
	changes.clear(); r = host.execute_group(1, 970007)
	check(str(r.status) == "ran" and r.adapters == ["opcode197_region_record"] and changes == [["0x22d10:region:65", "bit_0x19_0x04", 1]], "arm 7 sets that bit on the adapter")
	changes.clear(); r = host.execute_group(1, 970010)
	check(str(r.status) == "ran" and r.adapters == ["opcode197_list_mark"] and changes == [["0x2b53c:65", "byte_0x09", 1]], "arm 10 marks the [0x2B53C] entry for 65 on the adapter (%s %s)" % [r.adapters, changes])
	changes.clear(); r = host.execute_group(1, 970011)
	check(str(r.status) == "ran" and r.adapters.is_empty() and changes.is_empty(), "arm 11 returns 1 and stores nothing")
	check(int(host.state[rec]["bit_0x1c_0x01"]) == 1 and int(host.state[rec]["bit_0x1c_0x02"]) == 1 and int(host.state[rec]["bit_0x1d_0x01"]) == 0, "the record's committed bits are the last stores (bits 0/1 set by arm 4, +0x1D bit 0 cleared by arm 9)")
	# Adapters off: the PROVEN arms still run, arms 6/7/10 refuse with the reason naming the adapter.
	host.set_adapters_enabled(false)
	changes.clear(); r = host.execute_group(1, 970002)
	check(str(r.status) == "ran" and changes == [[rec, "bit_0x1c_0x01", 1]], "arm 2 runs with the adapters off")
	r = host.execute_group(1, 970007)
	check(str(r.status) == "unhosted" and str(r.reasons[0]).contains("opcode197_region_record"), "arm 7 refuses with the adapters off (%s)" % [r.reasons])
	r = host.execute_group(1, 970010)
	check(str(r.status) == "unhosted" and str(r.reasons[0]).contains("opcode197_list_mark"), "arm 10 refuses with the adapters off (%s)" % [r.reasons])
	host.set_adapters_enabled(true)
	# Real groups. L10 stream 1 group 11480: nine arm-4 sets, then opcode 196 (no handler) and opcode 9: the group stays
	# unhosted, but opcode 197 is no longer among its reasons.
	changes.clear(); r = host.execute_group(1, 11480)
	var about_197 := false
	for reason in r.reasons: if str(reason).contains("197"): about_197 = true
	check(str(r.status) == "unhosted" and not about_197 and str(r.reasons[0]).contains("opcode 196"), "L10 group 11480 (nine arm-4 sets) is blocked by opcode 196 only, not by 197 (%s)" % [r.reasons])
	# L10 stream 1 group 19732 (control 150's kind-6 record, caller byte 9): arm 10 on 65, two enqueues (controls 114/113),
	# local 11 = 1. Before this handler the group was blocked ("opcode 197 has no handler"); now it runs on the two adapters.
	var results: Array = host.fire_event("control:150", 6, {"caller_byte": 9, "context": "control:150"})
	check(results.size() == 1 and str(results[0].status) == "ran" and int(results[0].group) == 19732, "control 150's kind-6 event (caller byte 9) runs group 19732 (%s)" % [results[0].reasons if not results.is_empty() else []])
	check(results.size() == 1 and results[0].adapters.has("opcode197_list_mark") and results[0].adapters.has("opcode9_enqueue") and not results[0].adapters.has("opcode197_region_record"), "group 19732 runs on opcode197_list_mark and opcode9_enqueue (plus the target-binding adapters of the opcode-9 commands) (%s)" % [results[0].adapters if not results.is_empty() else []])
	check(int(host.locals.get(11, -1)) == 1, "group 19732 wrote local 11 = 1 natively (opcode 198), the Dracoid Ruins teleport gate (%s)" % [host.locals.get(11, -1)])
	var nested := []
	for n in host.enqueued_results: nested.append("%s:%d:%s" % [n.get("ref", "?"), int(n.group), str(n.status)])
	check(host.enqueued_results.size() == 2 and int(host.enqueued_results[0].group) == 19070 and int(host.enqueued_results[1].group) == 19052, "the enqueues fire controls 114 and 113 (kind 6, caller byte 0x14) -> groups 19070 and 19052 (%s)" % [nested])
	for n in host.enqueued_results: print("  enqueued group %d: %s %s %s" % [int(n.group), str(n.status), n.get("adapters", []), n.get("reasons", [])])
	# Other areas. L19 stream 0 group 918 (eight arm-0 clears, then opcode 9 arm 0x10 and opcode 1 on mode-1 movables): blocked, not by 197.
	host = Host.new(); changes.clear()
	host.object_state_changed.connect(func(ref: String, field: String, value: int): changes.append([ref, field, value]))
	check(host.load_area("res://scripts/lol2/native_scripts/L19_BC.json").is_empty(), "L19_BC loads")
	r = host.execute_group(0, 918)
	about_197 = false
	for reason in r.reasons: if str(reason).contains("197"): about_197 = true
	check(str(r.status) == "unhosted" and not about_197, "L19 group 918 (eight arm-0 clears) is blocked by its later opcodes, not by 197 (%s)" % [r.reasons])
	# Pure opcode-197 groups run PROVEN with no adapter: L13 stream 1 group 9360 (arm 2 on 187), L1 stream 1 group 12556 (arm 5 on 1143).
	host = Host.new(); changes.clear()
	host.object_state_changed.connect(func(ref: String, field: String, value: int): changes.append([ref, field, value]))
	check(host.load_area("res://scripts/lol2/native_scripts/L13_RC.json").is_empty(), "L13_RC loads")
	r = host.execute_group(1, 9360)
	check(str(r.status) == "ran" and r.adapters.is_empty() and changes == [["0x22d0c:187", "bit_0x1c_0x01", 1]], "L13 group 9360 (arm 2 on 187) sets bit 0 of record 187, PROVEN (%s %s)" % [r.status, changes])
	r = host.execute_group(0, 1864)
	check(str(r.status) == "ran" and r.adapters == ["opcode197_list_mark"], "L13 group 1864 (arm 10 on 636) runs on opcode197_list_mark (%s)" % [r.get("reasons", [])])
	host = Host.new(); changes.clear()
	host.object_state_changed.connect(func(ref: String, field: String, value: int): changes.append([ref, field, value]))
	check(host.load_area("res://scripts/lol2/native_scripts/L1_DC.json").is_empty(), "L1_DC loads")
	r = host.execute_group(1, 12556)
	check(str(r.status) == "ran" and r.adapters.is_empty() and changes == [["0x22d0c:1143", "bit_0x1c_0x01", 0], ["0x22d0c:1143", "bit_0x1c_0x02", 0]], "L1 group 12556 (arm 5 on 1143) clears bits 0 and 1 of record 1143, PROVEN (%s %s)" % [r.status, changes])
	host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L16_CA.json").is_empty(), "L16_CA loads")
	r = host.execute_group(1, 49070)
	check(str(r.status) == "ran" and r.adapters == ["opcode197_region_record"], "L16 group 49070 (arm 7 on 10579) runs on opcode197_region_record (%s)" % [r.get("reasons", [])])
	print("native host op197: %d failures" % failures)
	if failures == 0: print("PASS native host opcode 197: arms 0-5/8/9 PROVEN bit stores on [0x22D0C] records, arms 6/7/10 on adapters, L10 group 19732 writes local 11 = 1")
	quit(0 if failures == 0 else 1)
