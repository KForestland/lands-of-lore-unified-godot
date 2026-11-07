extends SceneTree
## Headless checks of scripts/lol2/native_script_host.gd against the generated L7_DH export
## (tools/prepare_native_scripts.py) and synthetic groups. Values are the G95 HOST_CONTRACT and
## G97 steps 1-2 ones; matcher inputs use the report's own names.
const Host := preload("res://scripts/lol2/native_script_host.gd")
const AREA_PATH := "res://scripts/lol2/native_scripts/L7_DH.json"
const PIN_PATH := "res://scripts/lol2/native_scripts_source.json"
const DOOR := "movable:57"

var failed := false
var signals: Array[String] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)


func listen(host: RefCounted) -> void:
	signals.clear()
	host.connect("object_state_changed", func(ref: String, name: String, value: int) -> void: signals.append("field %s %s %d" % [ref, name, value]))
	host.connect("local_changed", func(index: int, value: int) -> void: signals.append("local %d %d" % [index, value]))
	host.connect("sound_request", func(request: int) -> void: signals.append("sound %d" % request))


func reasons_text(result: Dictionary) -> String:
	return " | ".join(PackedStringArray(result["reasons"] as Array))


## "group:status" for every result, in record order.
func summary(results: Array) -> String:
	var parts: PackedStringArray = []
	for row: Variant in results:
		var r: Dictionary = row as Dictionary
		parts.append("%d:%s" % [int(r["group"]), str(r["status"])])
	return ",".join(parts)


## Results that are not "rejected" (the original test was false for those records).
func active(results: Array) -> Array:
	return results.filter(func(row: Variant) -> bool: return str((row as Dictionary)["status"]) != "rejected")


func door_host() -> RefCounted:
	var host: RefCounted = Host.new()
	var error: String = str(host.call("load_area", AREA_PATH))
	check(error == "", "load_area: " + error)
	# Adapter (docs/DEVIATIONS.md): kind-0x20 slot 57 is movable 57 (G95 LIKELY).
	host.call("bind_target", "0x20:57", DOOR)
	listen(host)
	return host


func record_for(host: RefCounted, group: int) -> Dictionary:
	for row: Variant in host.call("object_records", "movable:57") as Array:
		if int((row as Dictionary)["group"]) == group:
			return row as Dictionary
	return {}


func kind9_input(dword_26: int, dword_1e: int, global_23331: int) -> Dictionary:
	return {"word0": 0x0002, "word2": 0x0004, "dword_26": dword_26, "dword_1e": dword_1e, "global_23331": global_23331}


## One host per check: a synthetic group of one command, run by execute_group.
func arm(hex: String, prepare: Callable = Callable()) -> Dictionary:
	var bytes: PackedByteArray = hex.hex_decode()
	var data := {"format": "lol2-native-scripts-2", "area": "ARMS", "source": {}, "predicate_table": {"entries": []},
		"groups": [{"stream": 1, "group": 1, "file_offset": 100, "commands": [
			{"opcode": int(bytes[0]), "kind": int(bytes[1]), "target": bytes.decode_u16(2), "file_offset": 106, "raw_hex": hex}]}],
		"objects": [{"ref": "movable:9", "placement_hex": "00".repeat(41), "events": [
			{"kind": 2, "raw_hex": "0a020000010000000000", "file_offset": 500},
			{"kind": 19, "raw_hex": "04130100", "file_offset": 510},
			{"kind": 2, "raw_hex": "0a020000020000000000", "file_offset": 514}]}]}
	var h: RefCounted = Host.new()
	check(str(h.call("load_area_data", data)) == "", "arm host load")
	if prepare.is_valid():
		prepare.call(h)
	var ran: Dictionary = h.call("execute_group", 1, 1) as Dictionary
	ran["host"] = h
	return ran


func status_of(row: Dictionary) -> String:
	return str(row["status"])


## G97 step3/3b/4 arms per class (kind byte -> class: 0x20 movable, 0x10 control, 3 prop, 2 actor).
func opcode_arms() -> void:
	var r: Dictionary = arm("092005000700")
	check(status_of(r) == "ran" and int((r.host as RefCounted).call("field", "0x20:5", "bit_0x14_0x80")) == 1, "op 9 arm 7 sets +0x14 bit 0x80")
	r = arm("092005001342")
	check(status_of(r) == "ran" and int((r.host as RefCounted).call("field", "0x20:5", "byte_0x26")) == 0x42, "op 9 arm 0x13 copies byte 5 to +0x26")
	r = arm("092005001400")
	check(status_of(r) == "unhosted" and reasons_text(r).contains("bit 0x80"), "op 9 arm 0x14 needs +0x15 bit 0x80")
	r = arm("092005001400", func(h: RefCounted) -> void: h.call("set_field", "0x20:5", "bit_0x15_0x80", 0))
	check(status_of(r) == "ran" and int((r.host as RefCounted).call("field", "0x20:5", "bit_0x17_0x04")) == 1, "op 9 arm 0x14 with bit 0x80 clear sets +0x17 bit 0x04")
	r = arm("092005002300")
	check(status_of(r) == "ran" and int((r.host as RefCounted).call("field", "0x20:5", "bit_0x14_0x10")) == 1, "op 9 arm 0x23 on a movable sets +0x14 bit 0x10")
	r = arm("091005002300")
	check(status_of(r) == "ran" and not ((r.host as RefCounted).get("state") as Dictionary).has("0x10:5"), "op 9 arm 0x23 on a control stores nothing")
	r = arm("090205002500")
	check(status_of(r) == "unhosted", "op 9 arm 0x25 on an actor is UNKNOWN")
	r = arm("090005000700")
	check(status_of(r) == "unhosted" and reasons_text(r).contains("selects no object"), "kind byte 0 selects no object")
	r = arm("0d10050000000000")
	check(status_of(r) == "ran", "op 13 on a control is a no-op")
	r = arm("0d02050000000000")
	check(status_of(r) == "ran" and (r["adapters"] as Array).has("opcode13_actor_a8") and int((r.host as RefCounted).call("field", "0x02:5", "byte_0xa8")) == 0 and int((r.host as RefCounted).call("field", "0x02:5", "byte_0xa9")) == 0 and int((r.host as RefCounted).call("field", "0x02:5", "bit_0xb8_0x01")) == 1 and int((r.host as RefCounted).call("field", "0x02:5", "word_0x7c")) == 0, "op 13 actor slot 0 stores byte 5 at +0xA8 and +0xA9, sets +0xB8 bit 0 and clears word +0x7C")
	r = arm("011005006400")
	check(status_of(r) == "ran" and not ((r.host as RefCounted).get("state") as Dictionary).has("0x10:5"), "op 1 on a control is a no-op")
	r = arm("070305000000")
	check(status_of(r) == "ran" and int((r.host as RefCounted).call("field", "0x03:5", "bit_0x36_0x01")) == 1 and int((r.host as RefCounted).call("field", "0x03:5", "bit_0x36_0x04")) == 1, "op 7 prop arm 0 sets +0x36 bits 0x05")
	r = arm("070305000900")
	check(status_of(r) == "unhosted", "op 7 prop arm 9 xor needs the bit")
	r = arm("070205000100")
	check(status_of(r) == "ran" and int((r.host as RefCounted).call("field", "0x02:5", "bit_0xb5_0x02")) == 1 and int((r.host as RefCounted).call("field", "0x02:5", "word_0x7c")) == 0, "op 7 actor arm 1")
	r = arm("072005000000")
	check(status_of(r) == "unhosted", "op 7 on a movable writes through UNKNOWN pointers")
	r = arm("020100001c45")
	check(status_of(r) == "unhosted" and reasons_text(r).contains("0x223D6"), "op 2 needs global 0x223D6")
	r = arm("020100001c45", func(h: RefCounted) -> void: h.call("set_global", 0x223D6, 0))
	check(status_of(r) == "ran" and int(((r.host as RefCounted).get("globals") as Dictionary)[0x223C8]) == 5 and int(((r.host as RefCounted).get("globals") as Dictionary)[0x223CC]) == 2, "op 2 arm 0x1C writes 0x223C8/0x223CC")
	r = arm("cc000700feff0900")
	check(status_of(r) == "ran" and int((r.host as RefCounted).call("field", "0x22d0c:7", "byte_0x22")) == 9, "op 204 -2 arm")
	r = arm("cc00000003003412")
	check(status_of(r) == "ran" and int((r.host as RefCounted).call("field", "0x22d08:3", "word_0x00")) == 0x1234 and int((r.host as RefCounted).call("field", "0x22d08:3", "bit_0x05_0x40")) == 1, "op 204 other arm")
	r = arm("cc000700ffff0900")
	check(status_of(r) == "unhosted", "op 204 -1 arm is UNKNOWN")
	# Opcode 14 on movable 9: the second kind-2 record (byte 6 = 1) gets byte +4 = 5.
	r = arm("0e20090000050100")
	check(status_of(r) == "ran" and int((((r.host as RefCounted).get("record_state") as Dictionary)[514] as Dictionary)["byte4"]) == 5 and str(r["adapters"]) == str(["slot_index_binding", "b71a0_bit_clear"]), "op 14 writes the selected kind-2 record: " + str(r))
	r = arm("0e20090000050100", func(h: RefCounted) -> void: h.call("set_adapters_enabled", false))
	check(status_of(r) == "unhosted", "op 14 without adapters is unhosted")
	r = arm("0e20090005050100")
	check(status_of(r) == "unhosted", "op 14 arm 5 is not decoded")


func _initialize() -> void:
	# 1. JSON load, pinned to the producer's sha256; G97 predicate table.
	var pins: Variant = JSON.parse_string(FileAccess.get_file_as_string(PIN_PATH))
	check(pins is Dictionary, "pin file missing; run tools/prepare_native_scripts.py --all --output-root <project>")
	var pinned := ""
	if pins is Dictionary:
		for row: Variant in (pins as Dictionary).get("areas", []) as Array:
			if str((row as Dictionary)["area"]) == "L7_DH":
				pinned = str((row as Dictionary)["output_sha256"])
	check(pinned != "" and FileAccess.get_sha256(AREA_PATH) == pinned, "L7_DH.json does not match its pinned sha256")
	var host: RefCounted = door_host()
	check((host.get("groups") as Dictionary).size() == 615, "L7_DH group count")
	check((host.get("group_files") as Dictionary).get("s1:13798", -1) == 4874205, "group 13798 must sit at file 4874205 (G95)")
	check(str(host.call("group_opcodes", 1, 13798)) == "[198, 20, 5, 1]", "group 13798 opcodes")
	var table: Array = host.get("predicates") as Array
	check(table.size() == 255, "L7 predicate table count %d" % table.size())
	check((table[206] as PackedByteArray).hex_encode() == "0005000000" and (table[207] as PackedByteArray).hex_encode() == "0005000001"
		and (table[208] as PackedByteArray).hex_encode() == "0005000002" and (table[2] as PackedByteArray).hex_encode() == "0003020000", "G97 predicates 206/207/208/2")

	# 1b. G97 step 2b constructor state and the derived mode-6 angle word.
	var seeded: Dictionary = (host.get("state") as Dictionary).duplicate(true)
	var placements: Dictionary = host.get("placements") as Dictionary
	for ref: String in ["movable:56", "movable:57", "control:84", "control:1015"]:
		var p: PackedByteArray = placements[ref] as PackedByteArray
		check(int(host.call("field", ref, "byte_0x25")) == 0 and int(host.call("field", ref, "selector_0x3d")) == 0 and int(host.call("field", ref, "byte_0x26")) == int(p[0x1E]), "constructor state of " + ref)
	check(int((placements[DOOR] as PackedByteArray)[0x22]) == 6 and int((placements[DOOR] as PackedByteArray)[0x24]) == 60, "movable 57 placement bytes 0x22/0x24")
	check(str((host.get("attributes") as Dictionary)[DOOR]) == str({"mode": 6, "angle_word": 21845}), "movable 57 derived angle word " + str((host.get("attributes") as Dictionary)[DOOR]))
	check(int(host.call("field", DOOR, "byte_0x26")) == 50, "movable 57 +0x26 = placement +0x1E = 50")

	# 2. Group 13798 is unhosted while one of its opcodes has no handler; nothing runs.
	host.call("unregister_opcode", 1)
	var result: Dictionary = host.call("execute_group", 1, 13798) as Dictionary
	check(str(result["status"]) == "unhosted" and reasons_text(result) == "opcode 1 has no handler", "13798 without opcode 1: " + reasons_text(result))
	check(signals.is_empty() and (host.get("state") as Dictionary).recursive_equal(seeded, 4) and (host.get("locals") as Dictionary).is_empty(), "13798 partially ran without opcode 1")
	# No partial execution: opcode 1 refuses (no mode supplied) after 198, 20 and 5 were staged.
	host.call("register_builtins")
	host.set("attributes", {})
	result = host.call("execute_group", 1, 13798) as Dictionary
	check(str(result["status"]) == "unhosted" and reasons_text(result).contains("mode and angle word not"), "13798 without mode: " + reasons_text(result))
	check(signals.is_empty() and (host.get("state") as Dictionary).recursive_equal(seeded, 4) and (host.get("locals") as Dictionary).is_empty(), "staged 198/20/5 leaked after opcode 1 refused")

	# 3. Door 57 kind-4 records: mode 0, arg_c 0, then predicate 206/207/208 on the context +0x25.
	var expect_kind4: Array[String] = ["13702:ran,13720:rejected,13738:rejected", "13702:rejected,13720:ran,13738:rejected", "13702:rejected,13720:rejected,13738:ran"]
	var expect_signals: Array[String] = [str(["field movable:57 travel_0x50 21845", "field movable:57 byte_0x25 1"]),
		str(["field movable:57 travel_0x50 0", "field movable:57 byte_0x25 0"]), str(["sound 883", "field movable:57 byte_0x25 3"])]
	for value: int in [0, 1, 2]:
		host = door_host()
		host.call("set_field", DOOR, "byte_0x25", value)
		var fired: Array = host.call("fire_event", "movable:57", 4, {"arg_c": 0, "context": DOOR}) as Array
		check(summary(fired) == expect_kind4[value], "kind 4 with +0x25 = %d: %s" % [value, summary(fired)])
		check(str(signals) == expect_signals[value], "kind 4 +0x25 = %d effects %s" % [value, str(signals)])
	host = door_host()
	host.call("set_field", DOOR, "byte_0x25", 3)
	check(summary(host.call("fire_event", "movable:57", 4, {"arg_c": 0, "context": DOOR}) as Array) == "13702:rejected,13720:rejected,13738:rejected", "kind 4 with +0x25 = 3 must reject all")
	check(summary(host.call("fire_event", "movable:57", 4, {"arg_c": 1, "context": DOOR}) as Array) == "13702:rejected,13720:rejected,13738:rejected", "kind 4 with arg_c 1 must reject all")
	# (actor:57's +0x25 is seeded 0 at load since 2026-10-31, the constructor store; an actor without a placement stays unknown.)
	var unknown_context: Array = host.call("fire_event", "movable:57", 4, {"arg_c": 0, "context": "actor:9999"}) as Array
	check(summary(unknown_context) == "13702:unhosted,13720:unhosted,13738:unhosted" and reasons_text(unknown_context[0] as Dictionary).contains("actor:9999 +0x25, which is not known"), "kind 4 with an unknown context must be unhosted")
	check(signals.is_empty(), "rejected kind-4 records changed state")
	# Default context (0xB5000 -> 0xB71A0 on the same object): the door itself, seeded +0x25 = 0.
	host = door_host()
	check(summary(host.call("fire_event", "movable:57", 4, {"arg_c": 0}) as Array) == "13702:ran,13720:rejected,13738:rejected", "kind 4 default context must be the door")
	check(summary(host.call("fire_event", "movable:57", 4, {"arg_c": 0}) as Array) == "13702:rejected,13720:ran,13738:rejected", "second use must close (+0x25 1 -> predicate 207)")
	check(int(host.call("field", DOOR, "travel_0x50")) == 0 and int(host.call("field", DOOR, "byte_0x25")) == 0, "door 57 closed again")
	# Adapters used by a door use: index binding, and the unknown +0x15 bits 0x80 / 0x10.
	host = door_host()
	var door_run: Array = active(host.call("fire_event", "movable:57", 4, {"arg_c": 0}) as Array)
	check(str((door_run[0] as Dictionary)["adapters"]) == str(["b5000_bit_clear", "b71a0_bit_clear", "slot_index_binding"]), "door adapters " + str((door_run[0] as Dictionary).get("adapters")))
	# Known bits: +0x15 bit 0x80 set skips the walk (0xB5000), so nothing runs.
	host = door_host()
	host.call("set_field", DOOR, "bit_0x15_0x80", 1)
	var skipped: Array = host.call("fire_event", "movable:57", 4, {"arg_c": 0}) as Array
	check(summary(skipped) == "13702:rejected,13720:rejected,13738:rejected" and reasons_text(skipped[0] as Dictionary).contains("skips the walk"), "bit 0x80 must skip the kind-4 walk")
	# Known clear bits: PROVEN context, no bit adapters.
	host = door_host()
	host.call("set_field", DOOR, "bit_0x15_0x80", 0)
	host.call("set_field", DOOR, "bit_0x15_0x10", 0)
	door_run = active(host.call("fire_event", "movable:57", 4, {"arg_c": 0}) as Array)
	check(str((door_run[0] as Dictionary)["adapters"]) == str(["slot_index_binding"]), "known bits leave only the binding adapter " + str((door_run[0] as Dictionary).get("adapters")))
	# G97 step 2b predicate paths: operator 5 (signed <), operator 6 (both nonzero), left type 2 (0x26E58).
	host.set("predicates", [PackedByteArray([5, 5, 0, 0, 3]), PackedByteArray([6, 5, 0, 0, 1]), PackedByteArray([0, 2, 4, 0, 1]), PackedByteArray([0, 4, 0, 0, 0]), PackedByteArray([0, 5, 0, 4, 0])] as Array[PackedByteArray])
	var ok: Dictionary = {"status": "match"}
	var ctx: Dictionary = {"context": DOOR}
	host.call("set_field", DOOR, "byte_0x25", 2)
	check(str((host.call("_evaluate_predicate", 0, ctx, ok) as Dictionary)["status"]) == "match", "operator 5: 2 < 3")
	host.call("set_field", DOOR, "byte_0x25", 3)
	check(str((host.call("_evaluate_predicate", 0, ctx, ok) as Dictionary)["status"]) == "rejected", "operator 5: 3 < 3 is false")
	check(str((host.call("_evaluate_predicate", 1, ctx, ok) as Dictionary)["status"]) == "match", "operator 6: 3 and 1 nonzero")
	host.call("set_field", DOOR, "byte_0x25", 0)
	check(str((host.call("_evaluate_predicate", 1, ctx, ok) as Dictionary)["status"]) == "rejected", "operator 6: 0 and 1")
	check(str((host.call("_evaluate_predicate", 2, ctx, ok) as Dictionary)["status"]) == "unhosted", "left type 2 unseeded must be unhosted")
	host.call("set_local_e58", 4, 1)
	check(str((host.call("_evaluate_predicate", 2, ctx, ok) as Dictionary)["status"]) == "match" and (host.get("locals") as Dictionary).is_empty(), "left type 2 reads 0x26E58, not locals")
	check(str((host.call("_evaluate_predicate", 3, ctx, ok) as Dictionary)["status"]) == "unhosted" and str((host.call("_evaluate_predicate", 4, ctx, ok) as Dictionary)["status"]) == "unhosted", "left/right type 4 must stay unhosted")

	# 4. Door 57 kind-9 records: masks 0x010E/0x0004, mode 4 thresholds 0x28/0x1E/0x14, then 13832 mode 1. 0xAE2C8 enqueues one
	# record per hit (Grok backlog 4 item 3 PROVEN: a nonzero success count leaves before the next record is tested) and bit 7 of
	# byte +9 clears the mode after the enqueue, so mode 0 (slot 0) admits nothing: three hits at dword_26 <= 0x14 step the
	# selector 1, 2, 3. (Until 2026-10-31 the host ran every admitting record of one hit; that was never in HOST_CONTRACT.md.)
	host = door_host()
	var fired9: Array = host.call("fire_event", "movable:57", 9, kind9_input(0x15, 0, 0)) as Array
	check(summary(fired9) == "13774:ran,13786:not_reached,13798:not_reached,13832:not_reached", "kind 9 dword_26 0x15, hit 1: " + summary(fired9))
	check(int(host.call("field", DOOR, "selector_0x3d")) == 1, "kind 9 selector after 13774")
	fired9 = host.call("fire_event", "movable:57", 9, kind9_input(0x15, 0, 0)) as Array
	check(summary(fired9) == "13774:rejected,13786:ran,13798:not_reached,13832:not_reached" and int(host.call("field", DOOR, "selector_0x3d")) == 2, "kind 9 dword_26 0x15, hit 2 (13774 mode 0): " + summary(fired9))
	fired9 = host.call("fire_event", "movable:57", 9, kind9_input(0x15, 0, 0)) as Array
	check(summary(fired9) == "13774:rejected,13786:rejected,13798:rejected,13832:rejected", "kind 9 dword_26 0x15, hit 3 (13798 needs dword_26 <= 0x14): " + summary(fired9))
	host = door_host()
	for i in 2: host.call("fire_event", "movable:57", 9, kind9_input(0x14, 0, 0))
	signals.clear()
	fired9 = host.call("fire_event", "movable:57", 9, kind9_input(0x14, 0, 0)) as Array
	check(summary(fired9) == "13774:rejected,13786:rejected,13798:ran,13832:not_reached", "kind 9 dword_26 0x14, hit 3: " + summary(fired9))
	check(str(signals) == str(["local 2 1", "sound 784", "field movable:57 selector_0x3d 3", "field movable:57 travel_0x50 21845"]), "kind 9 13798 effects " + str(signals))
	# Bit 7 of byte +9 cleared byte +9 after the enqueue: mode 0 admits nothing, so a fourth hit reaches 13832 (rejected at dword_1e 0).
	check(int(host.call("record_byte", record_for(host, 13798), 9)) == 0, "13798 byte +9 must be 0 after its enqueue")
	fired9 = host.call("fire_event", "movable:57", 9, kind9_input(0x14, 0, 0)) as Array
	check(summary(fired9) == "13774:rejected,13786:rejected,13798:rejected,13832:rejected", "kind 9 fourth hit: " + summary(fired9))
	# Mask 0x010E shares no bit with word0 1.
	host = door_host()
	var masked: Dictionary = kind9_input(0x14, 0, 0)
	masked["word0"] = 1
	check(summary(host.call("fire_event", "movable:57", 9, masked) as Array) == "13774:rejected,13786:rejected,13798:rejected,13832:rejected", "kind 9 mask must reject word0 1")
	# Global 0x23331 == 5: byte +9 becomes 0 and nothing is enqueued; unknown global: unhosted.
	fired9 = host.call("fire_event", "movable:57", 9, kind9_input(0x14, 0, 5)) as Array
	check(summary(fired9) == "13774:rejected,13786:rejected,13798:rejected,13832:rejected" and signals.is_empty(), "kind 9 with global 5: " + summary(fired9))
	check(int(host.call("record_byte", record_for(host, 13798), 9)) == 0, "global 5 must write byte +9 = 0")
	host = door_host()
	var no_global: Dictionary = kind9_input(0x14, 0, 0)
	no_global.erase("global_23331")
	fired9 = host.call("fire_event", "movable:57", 9, no_global) as Array
	check(summary(fired9) == "13774:unhosted,13786:unhosted,13798:unhosted,13832:rejected" and reasons_text(fired9[2] as Dictionary).contains("global_23331"), "kind 9 without global: " + summary(fired9))

	# 5. Record 4883963 (group 13832, mode 1, byte +8 = 1) with trailer predicate 2 = locals[2] == 0.
	host = door_host()
	fired9 = host.call("fire_event", "movable:57", 9, kind9_input(0xFF, 1, 0)) as Array
	check(summary(fired9) == "13774:rejected,13786:rejected,13798:rejected,13832:unhosted" and reasons_text(fired9[3] as Dictionary).contains("local 2"), "13832 with unknown local 2: " + summary(fired9))
	check(int((fired9[3] as Dictionary)["record_file_offset"]) == 4883963, "13832 record file")
	host.call("set_local", 2, 0)
	fired9 = host.call("fire_event", "movable:57", 9, kind9_input(0xFF, 1, 0)) as Array
	check(summary(fired9).ends_with("13832:ran") and str(signals) == str(["sound 794"]), "13832 with local 2 = 0: " + summary(fired9) + str(signals))
	host.call("set_local", 2, 1)
	check(summary(host.call("fire_event", "movable:57", 9, kind9_input(0xFF, 1, 0)) as Array).ends_with("13832:rejected"), "13832 with local 2 = 1 must be rejected")
	check(summary(host.call("fire_event", "movable:57", 9, kind9_input(0xFF, 0, 0)) as Array).ends_with("13832:rejected"), "13832 mode 1 byte +8 1 > dword_1e 0 must be rejected")

	# 6. Region 83 event 2: byte +7 is 0; its trailer predicate 19 (0604120405) is operator 6 with left and right type 4 (unhosted).
	host = door_host()
	var region: Array = host.call("fire_event", "region:83", 2, {}) as Array
	check(summary(region) == "76:unhosted" and reasons_text(region[0] as Dictionary).contains("right type 4"), "region 83 event 2: " + summary(region))
	region = host.call("fire_event", "region:1338", 4, {}) as Array
	check(summary(region) == "794:unhosted" and reasons_text(region[0] as Dictionary).contains("event slot 4"), "region 1338 event 4: " + summary(region))
	check(signals.is_empty(), "unhosted region events changed state")

	# 7. Synthetic area: PROVEN-only groups, refusals, no partial execution, mode-6 travel 0 and 21845.
	var synthetic := {"format": "lol2-native-scripts-2", "area": "TEST", "source": {},
		"predicate_table": {"entries": ["0000000000", "0000000000", "0000000000", "0000000000", "0000000000", "0000000000", "0000000000", "0000000000"]},
		"groups": [
		{"stream": 1, "group": 100, "file_offset": 1000, "commands": [
			{"opcode": 16, "kind": 32, "target": 5, "file_offset": 1006, "raw_hex": "102005000700"},
			{"opcode": 5, "kind": 32, "target": 5, "file_offset": 1012, "raw_hex": "052005000200"},
			{"opcode": 198, "kind": 0, "target": 0, "file_offset": 1018, "raw_hex": "c60000000309"},
			{"opcode": 20, "kind": 32, "target": 5, "file_offset": 1024, "raw_hex": "14200500c40180000a14"},
			{"opcode": 1, "kind": 32, "target": 5, "file_offset": 1034, "raw_hex": "012005000000"}]},
		{"stream": 1, "group": 200, "file_offset": 2000, "commands": [
			{"opcode": 16, "kind": 32, "target": 5, "file_offset": 2006, "raw_hex": "102005000100"},
			{"opcode": 8, "kind": 32, "target": 5, "file_offset": 2012, "raw_hex": "082005000b000000"}]},
		{"stream": 1, "group": 300, "file_offset": 3000, "commands": [
			{"opcode": 16, "kind": 32, "target": 5, "file_offset": 3006, "raw_hex": "102005000100"},
			{"opcode": 9, "kind": 32, "target": 5, "file_offset": 3012, "raw_hex": "092005000400"}]},
		{"stream": 1, "group": 400, "file_offset": 4000, "commands": [
			{"opcode": 1, "kind": 32, "target": 5, "file_offset": 4006, "raw_hex": "012005006400"}]},
		{"stream": 1, "group": 500, "file_offset": 5000, "commands": [
			{"opcode": 5, "kind": 3, "target": 5, "file_offset": 5006, "raw_hex": "050305000200"}]},
		{"stream": 0, "group": 100, "file_offset": 6000, "commands": [
			{"opcode": 16, "kind": 32, "target": 6, "file_offset": 6006, "raw_hex": "102006000400"}]}],
		"objects": [{"ref": "movable:5", "events": [
			{"kind": 6, "stream": 1, "group": 100, "raw_hex": "060664000100", "file_offset": 10, "predicate": null},
			{"kind": 6, "stream": 1, "group": 200, "raw_hex": "0606c8000200", "file_offset": 16, "predicate": null},
			{"kind": 6, "stream": 1, "group": 300, "raw_hex": "06062c010300", "file_offset": 22, "predicate": null},
			{"kind": 6, "stream": 1, "group": 400, "raw_hex": "060690010400", "file_offset": 28, "predicate": null},
			{"kind": 8, "stream": 1, "group": 400, "raw_hex": "060890010400", "file_offset": 34,
				"predicate": {"index": 7, "trailer_hex": "04130700"}}]},
			{"ref": "region:9", "events": [
			{"kind": 12, "stream": 0, "group": 100, "raw_hex": "080c640009000200", "file_offset": 40, "predicate": null}]}]}
	var s: RefCounted = Host.new()
	listen(s)
	var error: String = str(s.call("load_area_data", synthetic))
	check(error == "", "synthetic load: " + error)
	s.call("set_target_attributes", "0x20:5", 6, 21845)
	var fired: Array = active(s.call("fire_event", "movable:5", 6, {"caller_byte": 1}) as Array)
	check(summary(fired) == "100:ran", "synthetic PROVEN group did not run: " + summary(fired))
	check(int(s.call("field", "0x20:5", "byte_0x25")) == 7 and int(s.call("field", "0x20:5", "selector_0x3d")) == 2, "synthetic 16/5 state")
	check(int((s.get("locals") as Dictionary)[3]) == 9, "synthetic 198 local")
	check(int(s.call("field", "0x20:5", "travel_0x50")) == 0, "percent 0 must write 0")
	check(str(signals) == str(["field 0x20:5 byte_0x25 7", "field 0x20:5 selector_0x3d 2", "local 3 9", "sound 452", "field 0x20:5 travel_0x50 0"]), "synthetic signal order " + str(signals))
	fired = active(s.call("fire_event", "movable:5", 6, {"caller_byte": 4}) as Array)
	check(summary(fired) == "400:ran" and int(s.call("field", "0x20:5", "travel_0x50")) == 21845, "percent 100 must write 21845")
	check((s.call("fire_event", "movable:5", 6, {}) as Array).size() == 4 and (s.get("unhosted") as Array).size() == 4, "kind 6 without caller_byte must be unhosted")
	s.set("unhosted", [] as Array[Dictionary])
	var before: Dictionary = (s.get("state") as Dictionary).duplicate(true)
	signals.clear()
	fired = active(s.call("fire_event", "movable:5", 6, {"caller_byte": 2}) as Array)
	# Opcode 8 arm 11 indexes the unread 0xB4390 table (arms 0-8/10 are hosted since 2026-10-31): the group stays refused.
	check(summary(fired) == "200:unhosted" and reasons_text(fired[0] as Dictionary).contains("opcode 8 arm 11"), "group 200 must be unhosted for opcode 8 arm 11: " + reasons_text(fired[0] as Dictionary))
	fired = active(s.call("fire_event", "movable:5", 6, {"caller_byte": 3}) as Array)
	check(summary(fired) == "300:unhosted" and reasons_text(fired[0] as Dictionary).contains("arm 0x04"), "group 300 must be refused by opcode 9 arm 4")
	check(signals.is_empty() and (s.get("state") as Dictionary).recursive_equal(before, 4), "a refused group changed state")
	# Opcode 5 on kind 3 (prop 0xF2944): +0x30 store through the adapter "opcode5_spatial".
	result = s.call("execute_group", 1, 500) as Dictionary
	check(str(result["status"]) == "ran" and str(result["adapters"]) == str(["opcode5_spatial"]) and int(s.call("field", "0x03:5", "byte_0x30")) == 2, "opcode 5 kind 3 adapter: " + str(result))
	check(str((s.get("adapter_log") as Array).map(func(row: Variant) -> int: return int((row as Dictionary)["group"]))) == "[100, 500]", "adapter log " + str(s.get("adapter_log")))
	# PROVEN only: the same groups are unhosted and change nothing.
	s.call("set_adapters_enabled", false)
	s.call("set_field", "0x03:5", "byte_0x30", 0)
	s.call("set_field", "0x20:5", "selector_0x3d", 0)
	before = (s.get("state") as Dictionary).duplicate(true)
	result = s.call("execute_group", 1, 500) as Dictionary
	check(str(result["status"]) == "unhosted" and reasons_text(result).contains("0xF1F94"), "PROVEN-only opcode 5 kind 3 must be unhosted")
	result = s.call("execute_group", 1, 100) as Dictionary
	check(str(result["status"]) == "unhosted" and reasons_text(result).contains("+0x3B"), "PROVEN-only group 100 must be unhosted on opcode 5")
	check((s.get("state") as Dictionary).recursive_equal(before, 4), "PROVEN-only refusals changed state")
	s.call("set_adapters_enabled", true)
	fired = s.call("fire_event", "movable:5", 8, {"arg": 4}) as Array
	check(summary(fired) == "400:unhosted" and reasons_text(fired[0] as Dictionary).contains("left type 0"), "undecoded predicate must be unhosted")
	check(summary(s.call("fire_event", "movable:5", 8, {"arg": 5}) as Array) == "400:rejected", "kind 8 word 4 != arg 5 must be rejected")
	s.call("set_target_attributes", "0x20:5", 1, 21845)
	# Mode 1 (backlog 5 item 9, 2026-10-31): refused with the adapter opcode1_other_modes off; with it on the not-equal path's
	# PROVEN store stages the same travel word ((byte 4 * word +0x4E) / 100) and the continuation is not modelled.
	s.call("set_adapter_enabled", "opcode1_other_modes", false)
	result = s.call("execute_group", 1, 400) as Dictionary
	check(str(result["status"]) == "unhosted" and reasons_text(result).contains("mode 1"), "mode 1 must be refused without opcode1_other_modes")
	s.call("set_adapter_enabled", "opcode1_other_modes", true)
	fired = s.call("fire_event", "region:9", 2, {}) as Array
	check(summary(fired) == "100:ran" and int(s.call("field", "0x20:6", "byte_0x25")) == 4, "synthetic region event 2 value 0")
	check((s.call("fire_event", "region:9", 3, {}) as Array).is_empty(), "region event 3 must not select an event-2 record")
	check((s.get("unhosted") as Array).size() == 6, "synthetic unhosted log size %d" % (s.get("unhosted") as Array).size())
	opcode_arms()
	if not failed:
		print("PASS native_script_host_test: L7_DH load + G97 predicate table, door 57 kind-4 predicates 206/207/208, kind-9 masks/mode 4/mode 1/bit 7, trailer predicate 2 on locals[2], G97 2b constructor state, derived angle word, default kind-4 context, operators 5/6, left type 2, region 83 type 4 unhosted, no partial execution, mode-6 travel 0 and 21845")
	quit(1 if failed else 0)
