extends SceneTree
## Grok backlog 4 item 0 (host adapters round 3, step 1): opcode 2 arms 0x26/0x27/5/0x0C/0x0B/57 on the object at encoded
## 0x22574 (adapters opcode2_lock_flags / opcode2_object_ad / opcode2_counters / opcode2_arm57) and the opcode-13 actor
## slots 6/10 (PROVEN stores behind the +0xA8 gate, adapter opcode13_actor_a8). Real groups: L7 14102 (Rix's first talk)
## and 14234 (the exorcism) now run whole; L4 8474 (a fish death: 198, 21, 2 arm 57); L8 s1:1498 (arm 0x27). Arm 6 (L7 14186)
## and the other opcode-13 slots stay refused. The PROVEN 0x1C arm is unchanged (native_script_host_test).
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func cmd(hex: String) -> Dictionary:
	var b := PackedByteArray(); b.resize(0); b = hex.hex_decode()
	return {"opcode": int(b[0]), "kind": int(b[1]), "target": b.decode_u16(2), "file_offset": -1, "bytes": b, "raw_hex": hex}
func one(host, hex: String, group := 970000) -> Dictionary:
	host.groups[host.group_key(1, group)] = [cmd(hex)]
	return host.execute_group(1, group)
func reason(r: Dictionary) -> String: return str(r.reasons[0]) if not r.get("reasons", []).is_empty() else ""
func fresh(area: String, d4: int = 0) -> RefCounted:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/%s.json" % area).is_empty(), "%s loads" % area)
	if d4 >= 0: host.set_global(0x223D4, d4)
	return host
func run() -> void:
	var O: String = Host.OBJ_22574
	# --- L7_DH: Rix's first talk (14102) and the exorcism (14234) run whole on the adapters.
	var host = fresh("L7_DH")
	var r: Dictionary = host.execute_group(1, 14102)
	check(str(r.status) == "ran", "L7 group 14102 (11 commands: 2x26, 2x05, 198, 8, 16, 13, 13, 5, 8, 8, 8) runs (%s)" % reason(r))
	for a in ["opcode2_lock_flags", "opcode2_object_ad", "opcode13_actor_a8", "slot_index_binding", "opcode8_gates"]:
		check(r.get("adapters", []).has(a), "14102 used adapter %s (%s)" % [a, r.get("adapters", [])])
	check(host.field(O, "bit_0x228_0x80") == 1 and host.field(O, "bit_0x228_0x10") == 0 and host.field(O, "byte_0x1b6") == 0 and host.field(O, "word_0x20a") == 0 and host.field(O, "bit_0x227_0x01") == 0, "arm 0x26: +0x228 bit 0x80 set, bit 0x10 clear, the 0xD0138 reset zeroes staged on %s" % O)
	check(host.field(O, "object_0xad_kind") == 2 and host.field(O, "object_0xad_index") == 57 and host.field(O, "bit_0x228_0x01") == 1, "arm 5 (020239000501): actor 57 bound at +0xAD, +0x228 bit 0 set (byte 5 = 1)")
	check(host.field("actor:57", "byte_0x25") == 1 and int(host.locals.get(10, -1)) == 1, "14102 stores actor 57 +0x25 = 1 and local 10 = 1 (PROVEN opcodes 16/198 as before)")
	check(host.field("actor:57", "bit_0xb5_0x01") == 1 and host.field("actor:57", "bit_0xb5_0x04") == 0 and host.field("actor:57", "bit_0xb5_0x08") == 0 and host.field("actor:57", "word_0x7c") == 0, "opcode 13 actor slots 6 and 10: +0xB5 bit 0 set, bits 2/3 clear, word +0x7C = 0")
	r = host.execute_group(1, 14234)
	check(str(r.status) == "ran" and r.adapters.has("opcode2_counters"), "L7 group 14234 (the exorcism, 13 commands) runs whole (%s)" % reason(r))
	check(host.field("actor:57", "byte_0x25") == 5 and host.field(O, "dword_0x15d_added") == 300 and host.field(O, "dword_0x159_added") == 300, "14234: +0x25 = 5; arms 0x0C/0x0B add 3 * 100 into +0x15D / +0x159 of %s (%d/%d)" % [O, host.field(O, "dword_0x15d_added"), host.field(O, "dword_0x159_added")])
	r = host.execute_group(1, 14234)
	check(str(r.status) == "ran" and host.field(O, "dword_0x15d_added") == 600, "the hosted sum accumulates over runs (600)")
	r = host.execute_group(1, 14186)
	check(str(r.status) == "ran" and r.adapters.has("opcode2_arm6_object") and host.field("actor:57", "opcode2_arm6_calls") == 1 and host.field("actor:57", "bit_0xb5_0x08") == 1 and host.field("actor:57", "bit_0xb5_0x01") == 0, "L7 group 14186 runs (Grok arm-6 answer: arm 6 on adapter opcode2_arm6_object, slots 0x0D/7 PROVEN) (%s)" % reason(r))
	# --- The 0x223D4 gate: nonzero -> no store, unknown -> refused.
	host = fresh("L7_DH", 1)
	r = host.execute_group(1, 14234)
	check(str(r.status) == "ran" and host.field(O, "dword_0x15d_added") == -1 and host.field("actor:57", "byte_0x25") == 5, "with 0x223D4 = 1 the arms 0x0C/0x0B return without a store and the rest of 14234 runs")
	host = fresh("L7_DH", -1)
	r = host.execute_group(1, 14234)
	check(str(r.status) == "unhosted" and reason(r).contains("0x223D4"), "with 0x223D4 unknown the counter arms refuse (%s)" % reason(r))
	# --- Adapters off: every new arm refuses by name; the opcode-13 slot needs +0xA8.
	host = fresh("L7_DH")
	host.set_adapters_enabled(false)
	check(reason(one(host, "020100002600")).contains("opcode2_lock_flags off") and reason(one(host, "020100002700")).contains("opcode2_lock_flags off"), "arms 0x26/0x27 refuse with opcode2_lock_flags off")
	check(reason(one(host, "020239000501")).contains("opcode2_object_ad off"), "arm 5 refuses with opcode2_object_ad off")
	check(reason(one(host, "020100000c03")).contains("opcode2_counters off") and reason(one(host, "020100000b03")).contains("opcode2_counters off"), "arms 0x0C/0x0B refuse with opcode2_counters off")
	check(reason(one(host, "020100003900")).contains("opcode2_arm57 off"), "arm 57 refuses with opcode2_arm57 off")
	check(reason(one(host, "0d02390006000000")).contains("+0xA8"), "opcode 13 actor slot 6 refuses while +0xA8 is not known and the adapter is off")
	check(reason(one(host, "020100001100")).contains("arm not decoded"), "arm 0x11 stays refused")
	# --- +0xA8 known: 0x0F skips the store (PROVEN), another value stores PROVEN without the adapter.
	host = fresh("L7_DH")
	host.set_adapters_enabled(false)
	host.set_adapter_enabled("slot_index_binding", true)
	host.set_field("actor:57", "byte_0xa8", 0x0F)
	r = one(host, "0d02390006000000")
	check(str(r.status) == "ran" and host.field("actor:57", "bit_0xb5_0x01") == -1 and host.field("actor:57", "word_0x7c") == -1, "actor +0xA8 == 0x0F: slot 6 returns 1 without a store")
	host.set_field("actor:57", "byte_0xa8", 3)
	r = one(host, "0d0239000a000000")
	check(str(r.status) == "ran" and not r.adapters.has("opcode13_actor_a8") and host.field("actor:57", "bit_0xb5_0x04") == 0 and host.field("actor:57", "word_0x7c") == 0, "actor +0xA8 known (3): slot 10 stores PROVEN, no opcode13_actor_a8 use (%s)" % [r.adapters])
	r = one(host, "0d02390017000000")
	check(str(r.status) == "ran" and host.field("actor:57", "word_0x7c") == 0, "byte 4 above 0x16 stores 0 at word +0x7C")
	r = one(host, "0d02390007000000")
	check(str(r.status) == "ran" and host.field("actor:57", "bit_0xb5_0x01") == 0, "opcode 13 actor slot 7 clears +0xB5 bit 0 (PROVEN, +0xA8 known)")
	r = one(host, "0d0239000d000000")
	check(str(r.status) == "ran" and host.field("actor:57", "bit_0xb5_0x04") == 1 and host.field("actor:57", "bit_0xb5_0x08") == 1, "opcode 13 actor slot 0x0D sets +0xB5 bits 2/3 (PROVEN)")
	check(reason(one(host, "0d02390008000000")).contains("index 8"), "opcode 13 actor slot 8 stays refused")
	# --- L4_HJ: a fish-death group (198 local 49 = 1, opcode 21 'fishdeth', opcode 2 arm 57) runs on the adapters.
	host = fresh("L4_HJ")
	r = host.execute_group(0, 8474)
	check(str(r.status) == "ran" and r.adapters.has("opcode2_arm57") and r.adapters.has("opcode21_movie") and host.field(O, "bit_0x16_0x01") == 1 and int(host.locals.get(49, -1)) == 1, "L4 group 8474 runs: local 49 = 1, movie index 28, +0x16 bit 0 of %s set (%s %s)" % [O, str(r.status), reason(r)])
	host = fresh("L4_HJ", 1)
	r = host.execute_group(0, 8474)
	check(str(r.status) == "ran" and host.field(O, "bit_0x16_0x01") == -1, "with 0x223D4 = 1 arm 57 stores nothing")
	# --- L8_SJ s1:1498: arm 0x27 then opcode 9 arm 0x15 on prop 1121.
	host = fresh("L8_SJ")
	r = host.execute_group(1, 1498)
	check(str(r.status) == "ran" and host.field(O, "bit_0x228_0x80") == 0 and host.field(O, "bit_0x229_0x80") == 1 and host.field(O, "bit_0x228_0x10") == 1, "L8 s1:1498 runs: arm 0x27 clears +0x228 bit 0x80, sets +0x229 bit 0x80 and +0x228 bit 0x10 (%s)" % reason(r))
	# --- L1_DC s1:10608: arm 57 with opcode 21 index 35 and opcode 16 on control 135.
	host = fresh("L1_DC")
	r = host.execute_group(1, 10608)
	check(str(r.status) == "ran" and host.field(O, "bit_0x16_0x01") == 1, "L1 s1:10608 (arm 57, movie 35, opcode 16) runs (%s)" % reason(r))
	print("Native host opcode 2 arms: %d failures" % failures)
	if failures == 0: print("PASS native host op2: arms 0x26/0x27/5/0x0C/0x0B/57 on the 0x22574 object and opcode-13 actor slots 6/10 hosted on adapters; L7 14102 and 14234 run whole, L4 8474 / L8 1498 / L1 10608 run; arm 6 and the other opcode-13 slots refused; 0x223D4 gate honoured")
	quit(0 if failures == 0 else 1)
