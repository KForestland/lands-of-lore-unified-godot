extends SceneTree
## Grok backlog 4 item 4 (host adapters round 3, step 6): opcodes 15, 18, 19 and 208 in their Act 1 forms. Opcode 15 forms
## (byte 4 <= 0x70) emit effect_request(form, object, lookup) and store nothing; opcode 18 fills the 0xB7D5E slot once;
## opcode 19 (byte 9 not 1/2) emits the 0x66130 record for slot +0x80; opcode 208 byte 4 == 0 raises/clears the 0x26B4E/0x26B52
## cells. Real groups: L4 s1:14784 (the Jungle tar prop 1350: 15 form 0x66 + 208 3/1 + 2/9/16/6/14), L4 s1:25286 (bramble control
## 109: 19 form 8 word 0x1C value 1), L5 s1:4170 (opcode 19 byte 9 = 1 stays refused).
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
var effects: Array = []
var records: Array = []
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func cmd(hex: String) -> Dictionary:
	var b := hex.hex_decode()
	return {"opcode": int(b[0]), "kind": int(b[1]), "target": b.decode_u16(2), "file_offset": 900000 + effects.size() + records.size(), "bytes": b, "raw_hex": hex}
func one(host, hex: String, group := 970000) -> Dictionary:
	host.groups[host.group_key(1, group)] = [cmd(hex)]
	return host.execute_group(1, group)
func reason(r: Dictionary) -> String: return str(r.reasons[0]) if not r.get("reasons", []).is_empty() else ""
func fresh(area: String) -> RefCounted:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/%s.json" % area).is_empty(), "%s loads" % area)
	host.set_global(0x223D4, 0)
	effects.clear(); records.clear()
	host.effect_request.connect(func(form: int, ref: String, lookup: String) -> void: effects.append([form, ref, lookup]))
	host.effect_record_request.connect(func(ref: String, w0: int, w2: int, v: int, b9: int) -> void: records.append([ref, w0, w2, v, b9]))
	return host
func run() -> void:
	# --- L4 tar group 14784 (prop 1350) runs whole on the adapters.
	var host = fresh("L4_HJ")
	var r: Dictionary = host.execute_group(1, 14784)
	check(str(r.status) == "ran", "L4 s1:14784 (tar prop 1350, 40 commands) runs (%s)" % reason(r))
	for a in ["opcode15_effect_request", "opcode208_cells", "opcode2_counters", "opcode6_gates"]:
		check(r.get("adapters", []).has(a), "14784 used adapter %s (%s)" % [a, r.get("adapters", [])])
	check(effects == [[0x66, "prop:1350", "prop:1350"]], "opcode 15 form 0x66 on prop 1350 looked up (3, 1350) = prop 1350 (%s)" % [effects])
	check(host.field("0x26b4e", "dword") == (60 << 16) and host.field("0x26b52", "byte") == 3, "opcode 208 (byte 5 3, byte 6 1): 0x26B4E = 60 << 16, 0x26B52 = 3 (%d/%d)" % [host.field("0x26b4e", "dword"), host.field("0x26b52", "byte")])
	check(host.field(Host.OBJ_22574, "dword_0x15d_added") == 100, "its opcode 2 arm 0x0C (byte 5 1) added 100 into +0x15D")
	# 208 only raises: a lower byte 6 / byte 5 leaves the cells; byte 5 == 0 clears both.
	r = one(host, "d090000000020100")
	check(str(r.status) == "ran" and host.field("0x26b4e", "dword") == (60 << 16) and host.field("0x26b52", "byte") == 3, "208 with byte 5 2 / byte 6 1 leaves higher cells")
	r = one(host, "d090000000050200")
	check(str(r.status) == "ran" and host.field("0x26b4e", "dword") == (120 << 16) and host.field("0x26b52", "byte") == 5, "208 with byte 5 5 / byte 6 2 raises both")
	r = one(host, "d090000000000000")
	check(str(r.status) == "ran" and host.field("0x26b4e", "dword") == 0 and host.field("0x26b52", "byte") == 0, "208 with byte 5 0 clears both cells")
	check(reason(one(host, "d090000001030100")).contains("byte 4 1"), "208 byte 4 == 1 (not an Act 1 form) is refused")
	# --- L4 bramble control 109, group 25286: opcode 19 form 8 (word +6 0x1C, byte 8 1, byte 9 0) and opcode 14 arm 0xEA (no write).
	r = host.execute_group(1, 25286)
	# The command's own kind byte is 1 (index 0): a kind the host binds to no class, so the record's object stays the raw ref 0x01:0.
	check(str(r.status) == "ran" and r.adapters.has("opcode19_effect_record") and records == [["0x01:0", 8, 0x1C, 1, 0]], "L4 s1:25286 (bramble control 109) runs: opcode 19 record on kind-1 index 0, word0 8, word2 0x1C, value 1 (%s %s)" % [reason(r), records])
	# Opcode 19 byte 9 outside 0/1/2 (0xEC, 0x70, 0x57 in Act 1): the dispatcher object pointer, value UNKNOWN; byte 9 = 1/2 refused.
	records.clear()
	r = one(host, "130100001000010005ec")
	check(str(r.status) == "ran" and records.size() == 1 and int(records[0][3]) == -1 and int(records[0][4]) == 0xEC, "opcode 19 byte 9 0xEC: record emitted with an UNKNOWN value (%s)" % [records])
	check(reason(one(host, "13022100000104005001")).contains("slot +0x8C"), "opcode 19 byte 9 1 (vtable percentage) is refused")
	var five = fresh("L5_HC")
	r = five.execute_group(1, 4170)
	check(str(r.status) == "unhosted" and reason(r).contains("opcode 19") and reason(r).contains("+0x8C"), "L5 s1:4170 stays blocked by its opcode-19 percentage form (%s)" % reason(r))
	# --- Opcode 18: the 0xB7D5E slot takes the first command and keeps it.
	r = one(host, "1203350556fb9d1800000908000000230000", 970010)
	var first: int = host.field("0xb7d5e", "command_file_offset")
	check(str(r.status) == "ran" and r.adapters.has("opcode18_pending_slot") and first > 0, "opcode 18 fills the empty 0xB7D5E slot with the command (%d)" % first)
	r = one(host, "1201000057f175010000050800c0000a0000", 970011)
	check(str(r.status) == "ran" and host.field("0xb7d5e", "command_file_offset") == first, "a second opcode 18 leaves the filled slot")
	check(reason(one(host, "1201000057f175010000250800c0000a0000")).contains("0x660F8"), "opcode 18 with bit 5 of the word +0xA set is refused (0x660F8 not modelled)")
	# --- Opcode 15: byte 4 above 0x70 is the epilogue (PROVEN no-op); a form on a control with a lookup of another kind.
	effects.clear()
	r = one(host, "0f0346057103460500")
	check(str(r.status) == "ran" and effects.is_empty() and not r.adapters.has("opcode15_effect_request"), "opcode 15 byte 4 0x71 is a PROVEN no-op")
	r = one(host, "0f106d006510390000")
	check(str(r.status) == "ran" and effects == [[0x65, "control:109", "control:57"]], "opcode 15 form 0x65 on control 109 with lookup (0x10, 57) (%s)" % [effects])
	# --- Adapters off: every new opcode refuses by name.
	host.set_adapters_enabled(false)
	check(reason(one(host, "0f03460566034605")).contains("opcode15_effect_request off"), "opcode 15 refuses with its adapter off")
	check(reason(one(host, "1203350556fb9d1800000908000000230000")).contains("opcode18_pending_slot off"), "opcode 18 refuses with its adapter off")
	check(reason(one(host, "1301000008001c000100")).contains("opcode19_effect_record off"), "opcode 19 refuses with its adapter off")
	check(reason(one(host, "d090000000030100")).contains("opcode208_cells off"), "opcode 208 refuses with its adapter off")
	print("Native host opcodes 15/18/19/208: %d failures" % failures)
	if failures == 0: print("PASS native host op15/18/19/208: tar group 14784 and bramble group 25286 run whole on adapters (effect_request 0x66, record 8/0x1C/1, cells 60<<16 / 3); opcode 18 slot once; percentage forms and byte 4 > 0 of 208 refused")
	quit(0 if failures == 0 else 1)
