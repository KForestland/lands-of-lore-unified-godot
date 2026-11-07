extends SceneTree
## Backlog 3 item 3 (opcode 6): PROVEN stores of arms 3-6 on the object's record (behind opcode6_gates), arms 0/1/2
## through opcode6_record, refusals with the adapters off, arm 7 refused, and every Act 1 opcode-6 command accepted.
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func cmd(arm: int, value: int, target: int = 76, kind: int = 0x10) -> Dictionary:
	var b := PackedByteArray([6, kind, target & 0xFF, (target >> 8) & 0xFF, arm, value & 0xFF])
	return {"opcode": 6, "kind": kind, "target": target, "file_offset": -1, "bytes": b, "raw_hex": b.hex_encode()}
func run() -> void:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L5_HC.json").is_empty(), "L5_HC loads")
	var changes: Array = []
	host.object_state_changed.connect(func(ref: String, field: String, value: int): changes.append([ref, field, value]))
	var g := 920000
	for probe in [[4, 0x14], [3, 0x0A], [5, 0x32], [6, 0xFA], [0, 0], [1, 0], [2, 0], [7, 0], [13, 0]]:
		host.groups[host.group_key(1, g)] = [cmd(int(probe[0]), int(probe[1]))]
		g += 1
	var record := "record:" + host.resolve("0x10:76")
	var r: Dictionary = host.execute_group(1, 920000)
	check(str(r.status) == "ran" and r.adapters.has("opcode6_gates") and not r.adapters.has("opcode6_record") and changes.has([record, "byte_0x0a", 0x14]), "arm 4 stores 0x14 at P+0xA (Hive group 5980 witness) behind the gates only")
	r = host.execute_group(1, 920001)
	check(str(r.status) == "ran" and changes.has([record, "byte_0x09", 0x0A]), "arm 3 stores 0x0A at P+9")
	r = host.execute_group(1, 920002)
	check(str(r.status) == "ran" and changes.has([record, "byte_0x08", 0x32]), "arm 5 stores at P+8")
	r = host.execute_group(1, 920003)
	check(str(r.status) == "ran" and changes.has([record, "word_0x06", 0xFA]), "arm 6 stores the zero-extended byte as the word at P+6")
	r = host.execute_group(1, 920004)
	check(str(r.status) == "ran" and r.adapters.has("opcode6_record") and changes.has([record, "byte_0x0d", 1]), "arm 0 starts the record (adapter opcode6_record)")
	r = host.execute_group(1, 920005)
	check(str(r.status) == "ran" and changes.has([record, "list_0x22d10", 1]), "arm 1 adds the list move")
	r = host.execute_group(1, 920006)
	check(str(r.status) == "ran" and changes.has([record, "bit_0x02_0x80", 1]), "arm 2 sets bit 0x80 of P+2")
	r = host.execute_group(1, 920007)
	check(str(r.status) == "unhosted" and str(r.reasons[0]).contains("arm 7"), "arm 7 has no given effect: refused")
	r = host.execute_group(1, 920008)
	check(str(r.status) == "ran" and not r.adapters.has("opcode6_record"), "arm 13 returns 1 without a record store: no-op")
	host.set_adapter_enabled("opcode6_record", false)
	r = host.execute_group(1, 920004)
	check(str(r.status) == "unhosted" and str(r.reasons[0]).contains("opcode6_record"), "arm 0 refuses with opcode6_record off")
	r = host.execute_group(1, 920000)
	check(str(r.status) == "ran", "arm 4 still runs with only the gates adapter")
	host.set_adapter_enabled("opcode6_gates", false)
	r = host.execute_group(1, 920000)
	check(str(r.status) == "unhosted" and str(r.reasons[0]).contains("0x200"), "arm 4 refuses with opcode6_gates off")
	host.set_adapters_enabled(true)
	var total := 0
	var refused := 0
	for area in ["L1_DC", "L3_DH", "L4_HJ", "L5_HC", "L7_DH"]:
		var h = Host.new()
		check(h.load_area("res://scripts/lol2/native_scripts/%s.json" % area).is_empty(), area + " loads")
		for key in h.groups:
			var n := 0
			for c in h.groups[key]: if int(c.opcode) == 6: n += 1
			if n == 0: continue
			total += n
			var res: Dictionary = h.execute_group(int(str(key).get_slice(":", 0)), int(str(key).get_slice(":", 1)))
			for reason in res.reasons: if str(reason).contains("opcode 6 "): refused += 1
			h.reset_state()
	check(total == 433 and refused == 0, "Act 1: %d opcode-6 commands, none refused by the handler (%d)" % [total, refused])
	print("Native host opcode 6: %d failures" % failures)
	if failures == 0: print("PASS native host opcode 6: PROVEN stores 3-6 on the object's record behind the gates adapter, arms 0/1/2 through opcode6_record, arm 7 refused, 433 Act 1 commands accepted")
	quit(0 if failures == 0 else 1)
