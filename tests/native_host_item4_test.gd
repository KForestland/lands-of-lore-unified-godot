extends SceneTree
## Backlog 3 item 4: opcode 14 arms 3/4 on the object's kind-2 record (opcode14_timer), opcode 9 arm 2 (opcode9_release)
## and arm 0x15 (opcode9_enqueue: the object's kind-6 event with caller byte 0x14 is fired after the commit), on real
## L3_DH / L1_DC objects, refusals with the adapters off, and every Act 1 command of those arms accepted.
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func cmd(hex: String) -> Dictionary:
	var b: PackedByteArray = hex.hex_decode()
	return {"opcode": int(b[0]), "kind": int(b[1]), "target": b.decode_u16(2), "file_offset": -1, "bytes": b, "raw_hex": hex}
func run() -> void:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L3_DH.json").is_empty(), "L3_DH loads")
	var records: Array = []
	host.record_state_changed.connect(func(r: int, f: String, v: int): records.append([r, f, v]))
	# Witnesses: 0e033b0103010000 (arm 3, byte 5 = 1 on prop 315) and 0e03e20004030000 (arm 4, byte 5 = 3 on prop 226).
	host.groups[host.group_key(1, 930000)] = [cmd("0e033b0103010000")]
	host.groups[host.group_key(1, 930001)] = [cmd("0e03e20004030000")]
	var r: Dictionary = host.execute_group(1, 930000)
	var started := records.filter(func(x): return str(x[1]) == "listed" and int(x[2]) == 1).size()
	var byte5 := records.filter(func(x): return str(x[1]) == "byte5" and (int(x[2]) & 0x80) != 0 and (int(x[2]) & 1) == 0).size()
	check(str(r.status) == "ran" and r.adapters.has("opcode14_timer") and started == 1 and byte5 == 1 and records.filter(func(x): return str(x[1]) == "word8").size() == 1, "arm 3 lists the record, sets bit 0x80, clears bit 0 and stores word +8 for byte 5 = 1 (witness 5883086) (%s %s)" % [r.status, r.get("reasons", [])])
	records.clear()
	r = host.execute_group(1, 930001)
	var stopped := records.filter(func(x): return str(x[1]) == "listed" and int(x[2]) == 0).size()
	var byte5b := records.filter(func(x): return str(x[1]) == "byte5" and (int(x[2]) & 0x80) == 0 and (int(x[2]) & 1) == 1).size()
	# The witness carries command byte 5 = 3, so the word +8 is stored; the record's byte +4 lacks bit 0x20 (a draw: UNKNOWN).
	check(str(r.status) == "ran" and stopped == 1 and byte5b == 1 and records.has([5849812, "word8", -1]), "arm 4 unlists the record, clears bit 0x80, sets bit 0, word +8 UNKNOWN for byte 5 = 3 (%s %s records %s)" % [r.status, r.get("reasons", []), records])
	host.set_adapter_enabled("opcode14_timer", false)
	r = host.execute_group(1, 930000)
	check(str(r.status) == "unhosted" and str(r.reasons[0]).contains("opcode14_timer"), "arm 3 refuses with opcode14_timer off")
	host.set_adapters_enabled(true)
	# Opcode 9 arm 2 (witness L1_DC 090237000200) and arm 0x15 (090398001500: prop 152's kind-6 event with byte 0x14).
	var l1 = Host.new()
	check(l1.load_area("res://scripts/lol2/native_scripts/L1_DC.json").is_empty(), "L1_DC loads")
	var changes: Array = []
	l1.object_state_changed.connect(func(ref: String, field: String, value: int): changes.append([ref, field, value]))
	var enq: Array = []
	l1.event_enqueued.connect(func(ref: String, kind: int, cb: int): enq.append([ref, kind, cb]))
	l1.groups[l1.group_key(1, 940000)] = [cmd("090237000200")]
	l1.groups[l1.group_key(1, 940001)] = [cmd("090398001500")]
	r = l1.execute_group(1, 940000)
	check(str(r.status) == "ran" and r.adapters.has("opcode9_release") and changes.has(["0x22cd8", "word_0x0c", 0]) and changes.has(["0x23c68", "byte_0x2d09", 0]), "arm 2 releases the player record and clears the 0x23C68 fields (%s %s)" % [r.status, r.get("reasons", [])])
	r = l1.execute_group(1, 940001)
	var ref := l1.resolve("0x03:152")
	check(str(r.status) == "ran" and r.adapters.has("opcode9_enqueue") and enq == [[ref, 6, 0x14]], "arm 0x15 enqueues prop 152's kind-6 event with caller byte 0x14 (%s %s)" % [r.status, enq])
	var kind6 := 0
	for rec in l1.object_records(ref): if int(rec.kind) == 6: kind6 += 1
	check(l1.enqueued_results.size() == kind6, "the enqueued event was fired: %d results for %d kind-6 records of %s" % [l1.enqueued_results.size(), kind6, ref])
	l1.set_adapter_enabled("opcode9_enqueue", false)
	r = l1.execute_group(1, 940001)
	check(str(r.status) == "unhosted" and str(r.reasons[0]).contains("opcode9_enqueue"), "arm 0x15 refuses with opcode9_enqueue off")
	l1.set_adapters_enabled(true)
	var counts := {"14:3": 0, "14:4": 0, "9:2": 0, "9:21": 0}
	var refused := 0
	for area in ["L1_DC", "L3_DH", "L4_HJ", "L5_HC", "L7_DH"]:
		var h = Host.new()
		check(h.load_area("res://scripts/lol2/native_scripts/%s.json" % area).is_empty(), area + " loads")
		for key in h.groups:
			var hit := false
			for c in h.groups[key]:
				var b: PackedByteArray = c.bytes
				if int(c.opcode) == 14 and (b[4] == 3 or b[4] == 4): counts["14:%d" % b[4]] += 1; hit = true
				if int(c.opcode) == 9 and (b[4] == 2 or b[4] == 0x15): counts["9:%d" % b[4]] += 1; hit = true
			if not hit: continue
			var res: Dictionary = h.execute_group(int(str(key).get_slice(":", 0)), int(str(key).get_slice(":", 1)))
			for reason in res.reasons:
				var s := str(reason)
				if s.contains("opcode 14 arm 3") or s.contains("opcode 14 arm 4") or s.contains("opcode 9 arm 0x02") or s.contains("opcode 9 arm 0x15"): refused += 1
			h.reset_state()
	check(counts["14:3"] == 395 and counts["14:4"] == 393 and counts["9:2"] == 467 and counts["9:21"] == 335 and refused == 0, "Act 1 commands of the four arms accepted (%s, refused %d)" % [counts, refused])
	print("Native host item 4: %d failures" % failures)
	if failures == 0: print("PASS native host item 4: opcode 14 arms 3/4 start/stop the kind-2 record, opcode 9 arm 2 releases the player, arm 0x15 enqueues and fires the kind-6 event, %s accepted" % [counts])
	quit(0 if failures == 0 else 1)
