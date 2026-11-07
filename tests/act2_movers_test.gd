extends SceneTree
## Grok backlog 6 item 1c (FABLE_TASK_MAPS_FINISH follow-up): the mover opcodes hosted. L8 control 70's groups 12702 (opcode 2 arm 0x18)
## and 12778 (opcode 3 kind 1 = give item) run; the movable 53/54 groups 13278/13320 run whole once opcode 2 arm 0x3C (item 1d: PROVEN
## return, stores on adapter opcode2_arm3c) is hosted; control 70's value-3 record matches through the kind-4 mode-3 matcher; L13's mode-0 / mode-2 movables take
## the opcode-1 travel word. Room stems table 46 slots. Adapters off = refusals; the binder's HOST_ADAPTERS_OFF map reverts per host.
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
var items := []
var rooms := []
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func cmd(hex: String) -> Dictionary:
	var b := hex.hex_decode()
	return {"opcode": int(b[0]), "kind": int(b[1]), "target": b.decode_u16(2), "file_offset": -1, "bytes": b, "raw_hex": hex}
func one(host, hex: String, group := 960000) -> Dictionary:
	host.groups[host.group_key(1, group)] = [cmd(hex)]
	return host.execute_group(1, group)
func reason(r: Dictionary) -> String: return str(r.reasons[0]) if not r.get("reasons", []).is_empty() else ""
func fresh(area: String) -> RefCounted:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/%s.json" % area).is_empty(), "%s loads" % area)
	host.set_global(0x223D6, 0); host.set_global(0x223D4, 0)
	host.item_request.connect(func(ref: String, identity: int, arg: int) -> void: items.append([ref, identity, arg]))
	host.room_request.connect(func(index: int, stem: String, archive: String) -> void: rooms.append([index, stem, archive]))
	return host
func run() -> void:
	var host = fresh("L8_SJ")
	check(host.room_stems.size() == 46 and str(host.room_stems[39].stem) == "settle1_" and str(host.room_stems[15].stem) == "magic_" and str(host.room_stems[43].archive) == "WPNEXT.MIX", "room stems: 46 slots, 39 settle1_, 15 magic_, 43 WPNEXT.MIX")
	# Control 70, group 12778 (kind-4 record value 0): give item identity 0xd0421bde, opcode 16 / 1 / 5.
	var r: Dictionary = host.execute_group(1, 12778)
	check(str(r.status) == "ran" and r.adapters.has("opcode3_item_grant") and items == [["0x01:0", 0xd0421bde, 4]], "L8 group 12778 runs: opcode 3 kind 1 emits item_request(0x01:0, 0xd0421bde, 4) (%s %s)" % [reason(r), items])
	# Control 70, group 12702 (kind-4 record value 3: the host's kind-4 matcher takes mode 0 only, so the group is run directly).
	r = host.execute_group(1, 12702)
	check(str(r.status) == "ran" and r.adapters.has("opcode2_arm18_clear") and host.field("0x23348", "dword_0x90b") == 0, "L8 group 12702 runs: arm 0x18 clears 0x23348+0x90B (%s)" % reason(r))
	# Control 70's value-3 kind-4 record (mode 3, backlog 6 item 1d): the argument object's +0x18 must be the record's dword d0421bde,
	# the identity its group 12778 gives; the use then runs 12702 through the matcher.
	host.reset_state(); host.set_global(0x223D6, 0); host.set_global(0x223D4, 0)
	# The three records sit behind predicates 206/207/208 (+0x25 of control 70 == 0 / 1 / 2) and each group's opcode 16 steps +0x25, so
	# one use runs one record: 12702 (mode 3) first, 12778 (mode 0) second, 12814 (mode 3) third.
	var fired: Array = host.fire_event("control:70", 4, {"arg_c": 0, "arg_object_identity": 0xd0421bde, "context": "control:70"})
	var status := {}
	for f in fired: status[int(f.group)] = str(f.status)
	check(status.get(12702, "") == "ran" and status.get(12778, "") == "rejected" and status.get(12814, "") == "rejected" and host.field("control:70", "byte_0x25") == 1, "use 1 with the item d0421bde: the mode-3 record 12702 runs through the matcher (+0x25 -> 1); 12778 / 12814 wait on predicates 207 / 208 (%s)" % [status])
	fired = host.fire_event("control:70", 4, {"arg_c": 0, "arg_object_identity": 0xd0421bde, "context": "control:70"})
	status = {}
	for f in fired: status[int(f.group)] = str(f.status)
	check(status.get(12778, "") == "ran" and status.get(12702, "") == "rejected" and host.field("control:70", "byte_0x25") == 2, "use 2: the mode-0 record 12778 runs (gives the item), +0x25 -> 2 (%s)" % [status])
	fired = host.fire_event("control:70", 4, {"arg_c": 0, "arg_object_identity": 0xd0421bde, "context": "control:70"})
	status = {}
	for f in fired: status[int(f.group)] = str(f.status)
	check(status.get(12814, "") == "ran", "use 3 with the item: the mode-3 record 12814 runs (%s)" % [status])
	host.reset_state(); host.set_global(0x223D6, 0); host.set_global(0x223D4, 0)
	fired = host.fire_event("control:70", 4, {"arg_c": 0, "arg_object_identity": 0, "context": "control:70"})
	status = {}
	for f in fired: status[int(f.group)] = str(f.status)
	check(status.get(12702, "") == "rejected" and str(fired[0].reasons[0]).contains("mode 3"), "use with no object (pointer 0): the mode-3 record rejects (%s)" % [status])
	fired = host.fire_event("control:70", 4, {"arg_c": 0, "context": "control:70"})
	check(fired.size() == 3 and str(fired[0].status) == "unhosted" and str(fired[0].reasons[0]).contains("arg_object_identity"), "mode 3 without the input is unhosted")
	# Movables 53 / 54: opcode 2 arm 0x3C returns 1 (PROVEN) and the groups run whole on the adapters.
	r = host.execute_group(1, 13278)
	check(str(r.status) == "ran" and r.adapters.has("opcode2_arm3c") and r.adapters.has("opcode12_room") and host.field(Host.OBJ_22574, "dword_0x1a2") == 0 and host.field(Host.OBJ_22574, "byte_0x199") == 0, "L8 group 13278 (movable 53) runs whole: arm 0x3C stages the 0xD6B20 zeros (%s %s)" % [reason(r), r.get("adapters", [])])
	r = host.execute_group(1, 13320)
	check(str(r.status) == "ran" and r.adapters.has("opcode210_arm9"), "L8 group 13320 (movable 54) runs whole (%s)" % reason(r))
	var off = fresh("L8_SJ")
	off.set_adapters_enabled(false)
	r = one(off, "020100003c00")
	check(str(r.status) == "ran" and off.field(Host.OBJ_22574, "dword_0x1a2") == -1, "arm 0x3C with the adapter off: the PROVEN return, no store")
	host.set_field(Host.OBJ_22574, "bit_0x228_0x10", 0)
	r = one(host, "020100003c00")
	check(str(r.status) == "ran" and host.field(Host.OBJ_22574, "dword_0x1a2") == 0, "arm 0x3C with +0x228 bit 0x10 clear takes the 0x80064 path (no new store; earlier zeros stay)")
	rooms.clear()
	r = one(host, "0c0366032700")
	check(str(r.status) == "ran" and r.adapters.has("opcode12_room") and rooms == [[39, "settle1_", "SETTLE1.MIX"]] and host.field("0x269c4", "bit_0x00_0x02") == 1, "opcode 12 slot 39 emits room_request settle1_ / SETTLE1.MIX and sets bit 1 of 0x269C4 (%s %s)" % [reason(r), rooms])
	r = one(host, "0c0366032e00")
	check(str(r.status) == "ran" and rooms.size() == 1, "opcode 12 index 46 is the native no-op (no room)")
	r = one(host, "d20000000900")
	check(str(r.status) == "ran" and r.adapters.has("opcode210_arm9") and host.field("0x26d1e", "word") == 0 and host.field("0x26d1c", "word") == 0, "opcode 210 arm 9 byte 5 = 0 stores word 0 (%s)" % reason(r))
	r = one(host, "d20000000902")
	check(str(r.status) == "ran" and host.field("0x26d1e", "word") == ((2 << 15) - 2) >> 8, "opcode 210 arm 9 byte 5 = 2 stores ((2 << 15) - 2) >> 8 = %d" % host.field("0x26d1e", "word"))
	check(str(one(host, "d20000000c00").status) == "ran" and reason(one(host, "d20000000300")).contains("arm 3"), "opcode 210: byte 4 above 0xB is a no-op, other arms refuse")
	# Adapters off.
	host.set_adapters_enabled(false)
	check(reason(one(host, "020100001800")).contains("opcode2_arm18_clear off") and reason(one(host, "03010000de1b42d004000000")).contains("opcode3_item_grant off") and reason(one(host, "0c0366032700")).contains("opcode12_room off") and reason(one(host, "d20000000900")).contains("opcode210_arm9 off"), "every mover adapter refuses by name when off")
	# L13: mode-0 and mode-2 movables take the travel word on the not-equal path (adapter opcode1_other_modes).
	var l13 = fresh("L13_RC")
	check(int(l13.attributes["movable:50"].mode) == 0 and int(l13.attributes["movable:50"].angle_word) == 0xC8 and int(l13.attributes["movable:77"].mode) == 2 and int(l13.attributes["movable:77"].angle_word) == 0x5F, "L13 movable 50 is mode 0 (+0x24 0xC8), movable 77 mode 2 (+0x24 0x5F)")
	r = one(l13, "012032006400")
	check(str(r.status) == "ran" and r.adapters.has("opcode1_other_modes") and l13.field("movable:50", "travel_0x50") == 0xC8, "L13 movable 50 (mode 0) byte 4 100 -> travel 0xC8")
	r = one(l13, "01204d006400")
	check(str(r.status) == "ran" and l13.field("movable:77", "travel_0x50") == 0x5F, "L13 movable 77 (mode 2) byte 4 100 -> travel 0x5F")
	r = one(l13, "012047000000")
	check(str(r.status) == "ran" and l13.field("movable:71", "travel_0x50") == 0, "L13 movable 71 byte 4 0 -> travel 0")
	var runnable := 0; var total := 0
	for key in l13.groups:
		var cmds: Array = l13.groups[key]
		var has_op1 := false
		for c in cmds: if int(c.opcode) == 1 and int(c.kind) == 0x20: has_op1 = true
		if not has_op1: continue
		total += 1
		var parts: Array = str(key).trim_prefix("s").split(":")
		if str(l13.execute_group(int(parts[0]), int(parts[1])).status) == "ran": runnable += 1
	print("L13 groups with opcode 1 on movables: %d, run whole on the host: %d" % [total, runnable])
	check(total > 0 and runnable > 0, "some L13 opcode-1 mover groups run whole")
	print("Act 2 movers: %d failures" % failures)
	if failures == 0: print("PASS act2 movers: opcode 2 arm 0x18, opcode 3 kind 1 (item_request), opcode 12 (room stems, 46 slots), opcode 210 arm 9 hosted on adapters; L13 mode 0/2 movables take the travel word; L8 groups 13278/13320 run whole with arm 0x3C (item 1d); control 70 kind-4 mode 3 through the matcher")
	quit(0 if failures == 0 else 1)
