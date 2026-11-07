extends SceneTree
## Backlog 3 item 2 (opcode 8): the host's opcode8_player (LIKELY arms 0/1/2/3/10 on the player record 0x22CD8) and
## opcode8_gates (bit 0x80000 and the 0x22CE0 gate taken as passing) adapters, the PROVEN stores of arms 4-8, refusals
## with the adapters off, arms above 10 refused, and every Act 1 opcode-8 command accepted by the handler.
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func cmd(arm: int, value: int, target: int = 5, kind: int = 0x10) -> Dictionary:
	var b := PackedByteArray([8, kind, target & 0xFF, (target >> 8) & 0xFF, arm, 0, value & 0xFF, (value >> 8) & 0xFF])
	return {"opcode": 8, "kind": kind, "target": target, "file_offset": -1, "bytes": b, "raw_hex": b.hex_encode()}
func run() -> void:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L3_DH.json").is_empty(), "L3_DH loads")
	var changes: Array = []
	host.object_state_changed.connect(func(ref: String, field: String, value: int): changes.append([ref, field, value]))
	var g := 910000
	for probe in [[0, 0], [1, 0], [2, 12], [3, 0], [4, 27], [5, 26], [6, 9], [7, 0xFF], [8, 0], [10, 4], [11, 0], [9, 0]]:
		host.groups[host.group_key(1, g)] = [cmd(int(probe[0]), int(probe[1]))]
		g += 1
	var r: Dictionary = host.execute_group(1, 910000)
	check(str(r.status) == "ran" and r.adapters.has("opcode8_player") and not r.adapters.has("opcode8_gates") and changes.has(["0x22cd8", "word_0x10", 5]), "arm 0 selects the object on the player record (adapter opcode8_player)")
	r = host.execute_group(1, 910001)
	check(str(r.status) == "ran" and r.adapters.has("opcode8_gates") and r.adapters.has("opcode8_player") and changes.has(["0x22cd8", "bit_0x14_0x8000", 0]), "arm 1 releases the record behind the bit gate")
	r = host.execute_group(1, 910002)
	check(str(r.status) == "ran" and changes.has(["0x22cd8", "value_0x9edf8", 12]), "arm 2 stores the command word (12)")
	r = host.execute_group(1, 910003)
	check(str(r.status) == "ran" and changes.has(["0x22cd8", "byte_0x3c_from_0x4e", 1]), "arm 3 copies +0x4E to +0x3C")
	r = host.execute_group(1, 910004)
	check(str(r.status) == "ran" and r.adapters.has("opcode8_gates") and not r.adapters.has("opcode8_player") and changes.has(["0x22ce0", "word_0x14", 27]), "arm 4 (PROVEN store) writes 27 at the 0x22CE0 pointer +0x14 behind the gates only")
	r = host.execute_group(1, 910005)
	check(str(r.status) == "ran" and changes.has(["0x22ce0", "word_0x1c", 26]), "arm 5 writes 26 at +0x1C")
	r = host.execute_group(1, 910006)
	check(str(r.status) == "ran" and changes.has(["0x22ce0", "word_0x11e", 9]), "arm 6 writes +0x1C and 0x15F03C's +0x11E for a positive value")
	r = host.execute_group(1, 910007)
	check(str(r.status) == "ran" and changes.has(["0x22ce0", "word_0x30", -1]), "arm 7 stores -1 for 0xFF at +0x30 (witness L1_DC 7329669)")
	r = host.execute_group(1, 910008)
	check(str(r.status) == "ran" and changes.has(["0x22cd8", "called_0x15ef3c", 1]), "arm 8 calls 0x15EF3C")
	r = host.execute_group(1, 910009)
	check(str(r.status) == "ran" and changes.has(["0x22cd8", "value_0x9ee70", 4]), "arm 10 stores the command word with flag 1")
	r = host.execute_group(1, 910010)
	check(str(r.status) == "unhosted" and str(r.reasons[0]).contains("0xB4390"), "arm 11 is refused (shared table not read)")
	r = host.execute_group(1, 910011)
	check(str(r.status) == "unhosted" and str(r.reasons[0]).contains("arm 9"), "arm 9 has no arm")
	host.set_adapter_enabled("opcode8_player", false)
	r = host.execute_group(1, 910000)
	check(str(r.status) == "unhosted" and str(r.reasons[0]).contains("opcode8_player"), "arm 0 refuses with opcode8_player off")
	r = host.execute_group(1, 910004)
	check(str(r.status) == "ran", "arm 4 still runs with only opcode8_gates (PROVEN store)")
	host.set_adapter_enabled("opcode8_gates", false)
	r = host.execute_group(1, 910004)
	check(str(r.status) == "unhosted" and str(r.reasons[0]).contains("0x80000"), "arm 4 refuses with opcode8_gates off (the bit is not known)")
	host.set_adapters_enabled(true)
	# Every Act 1 opcode-8 command is accepted by the handler (640 across the five areas).
	var total := 0
	var no_handler := 0
	for area in ["L1_DC", "L3_DH", "L4_HJ", "L5_HC", "L7_DH"]:
		var h = Host.new()
		check(h.load_area("res://scripts/lol2/native_scripts/%s.json" % area).is_empty(), area + " loads")
		for key in h.groups:
			var n := 0
			for c in h.groups[key]: if int(c.opcode) == 8: n += 1
			if n == 0: continue
			total += n
			var res: Dictionary = h.execute_group(int(str(key).get_slice(":", 0)), int(str(key).get_slice(":", 1)))
			for reason in res.reasons: if str(reason).contains("opcode 8 has no handler") or str(reason).contains("opcode 8 arm"): no_handler += 1
			h.reset_state()
	check(total == 640 and no_handler == 0, "Act 1: %d opcode-8 commands, none refused by the handler (%d)" % [total, no_handler])
	print("Native host opcode 8: %d failures" % failures)
	if failures == 0: print("PASS native host opcode 8: arms 0/1/2/3/10 on the player record (adapter), PROVEN stores 4-8 behind the gates adapter, arms 9/11+ refused, 640 Act 1 commands accepted")
	quit(0 if failures == 0 else 1)
