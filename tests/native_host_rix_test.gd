extends SceneTree
## Backlog 4 item 3 + ORIGINAL_BUGS row 1 (Rix): the fanfix 4882703 208 -> 207 as a load-time record patch, the kind-9 walk of
## actor 57's list (0xAE2C8: the first enqueued record ends the walk; a cleared mode byte admits nothing) and what then runs:
## hit 1 -> 14102 (whole); a hit with dword_1e >= 1 -> 14186 (whole: opcode 2 arm 6 on adapter opcode2_arm6_object, opcode 13 slots
## 7/0x0D PROVEN); the next hit with word0 bit 0x40 and dword_26 <= 100 -> 14234, the exorcism (whole, on adapters). Without the
## fix 14234 never admits (+0x25 == 2 is never stored).
const Host := preload("res://scripts/lol2/native_script_host.gd")
const AREA := "res://scripts/lol2/native_scripts/L7_DH.json"
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func predicate_of(host, ref: String, group: int) -> int:
	for rec in host.object_records(ref):
		if int(rec.get("group", -1)) == group and int(rec.kind) == 9: return int(rec.get("predicate", -1))
	return -2
func summary(results: Array) -> Array:
	var out := []
	for r in results: out.append("%d:%s" % [int(r.group), str(r.status)])
	return out
func status_of(results: Array, group: int) -> String:
	for r in results: if int(r.group) == group: return str(r.status)
	return "absent"
func reason_of(results: Array, group: int) -> String:
	for r in results: if int(r.group) == group: return str(r.reasons[0]) if not r.reasons.is_empty() else ""
	return ""
func hit(word0: int, dword_26: int, dword_1e: int) -> Dictionary:
	return {"word0": word0, "word2": 0, "dword_26": dword_26, "dword_1e": dword_1e, "global_23331": 0, "context": "actor:57"}
func fresh(fix := true) -> RefCounted:
	var host = Host.new()
	if not fix: host.set_adapter_enabled("rix_fanfix_208_207", false)
	check(host.load_area(AREA).is_empty(), "L7_DH loads")
	host.set_global(0x223D4, 0)
	return host
func run() -> void:
	var host = fresh()
	check(host.applied_patches.size() == 1 and int(host.applied_patches[0].file_offset) == 4882703 and int(host.applied_patches[0].from) == 208 and int(host.applied_patches[0].to) == 207 and str(host.applied_patches[0].object) == "actor:57", "the fanfix patched byte 4882703 208 -> 207 on actor 57's list (%s)" % [host.applied_patches])
	check(predicate_of(host, "actor:57", 14234) == 207 and predicate_of(host, "actor:57", 14102) == 206 and predicate_of(host, "actor:57", 14186) == 207, "group 14234's trailer now selects predicate 207 (+0x25 == 1) like 14186's; 14102 keeps 206 (+0x25 == 0)")
	var plain = fresh(false)
	check(plain.applied_patches.is_empty() and predicate_of(plain, "actor:57", 14234) == 208, "with the adapter off at load the trailer keeps predicate 208 (+0x25 == 2)")
	check(host.field("actor:57", "byte_0x25") == 0, "the actor constructor's +0x25 = 0 is seeded at load (0xAE990, PROVEN)")
	# Hit 1 (any word0, dword_26 <= 255): the first kind-9 record (14102, predicate 206) admits, is enqueued and ends the walk.
	var results: Array = host.fire_event("actor:57", 9, hit(0x20, 200, 30))
	check(status_of(results, 14102) == "ran" and status_of(results, 14186) == "not_reached" and status_of(results, 14234) == "not_reached" and status_of(results, 14414) == "not_reached", "hit 1: 14102 runs, the later kind-9 records are not reached (0xAE2C8 leaves on a nonzero count) (%s)" % [summary(results)])
	check(host.field("actor:57", "byte_0x25") == 1 and int(host.locals.get(10, -1)) == 1 and host.field(Host.OBJ_22574, "bit_0x228_0x80") == 1, "14102 stored +0x25 = 1, local 10 = 1 and the arm-0x26 flags")
	check(int(host.record_state.get(4882633, {}).get("byte9", -9)) == 0, "14102's record byte +9 is cleared after the enqueue (bit 7): one-shot (%s)" % [host.record_state.get(4882633, {})])
	# Hit 2 with dword_1e >= 1: 14102 (mode 0 now) admits nothing; 14186 admits (mode 1, byte +8 1 <= dword_1e) and is enqueued, so
	# 14234 is not reached; 14186's group stops on opcode 2 arm 6 (not in backlog 4) and opcode 13 slots 7/0x0D.
	results = host.fire_event("actor:57", 9, hit(0x40, 90, 30))
	check(status_of(results, 14102) == "rejected" and reason_of(results, 14102).contains("mode 0"), "hit 2: the consumed record 14102 admits nothing (mode 0) (%s)" % reason_of(results, 14102))
	check(status_of(results, 14186) == "ran" and status_of(results, 14234) == "not_reached", "hit 2: 14186 is enqueued first and runs whole (arm 6 + slots 0x0D/7 hosted); 14234 not reached (%s %s)" % [summary(results), reason_of(results, 14186)])
	check(host.field("actor:57", "bit_0xb5_0x01") == 0 and host.field("actor:57", "bit_0xb5_0x04") == 1 and host.field("actor:57", "bit_0xb5_0x08") == 1 and host.field("actor:57", "opcode2_arm6_calls") == 1 and int(host.locals.get(10, -1)) == 0 and host.field(Host.OBJ_22574, "bit_0x229_0x80") == 1, "14186: slot 0x0D sets +0xB5 bits 2/3, slot 7 clears bit 0, arm 6 counted on actor 57, local 10 = 0, arm 0x27 flags")
	# Hit 3 (bit 0x40, dword_26 <= 100): 14102 and 14186 are consumed (mode 0), 14234 admits and runs whole.
	results = host.fire_event("actor:57", 9, hit(0x40, 80, 30))
	check(status_of(results, 14186) == "rejected" and status_of(results, 14234) == "ran" and status_of(results, 14414) == "not_reached", "hit 3: the exorcism group 14234 runs after 14102 and 14186 (%s)" % [summary(results)])
	check(host.field("actor:57", "byte_0x25") == 5 and host.field(Host.OBJ_22574, "dword_0x15d_added") == 300, "hit 3: +0x25 = 5 and the +300 counters")
	# Hit 2 with dword_1e < 1: 14186 rejects (byte +8 1 > dword_1e), 14234 admits (mask 0x0040 in word0, 100 >= dword_26, predicate
	# 207 with +0x25 == 1) and runs whole: the exorcism group.
	var again = fresh()
	again.fire_event("actor:57", 9, hit(0x20, 200, 30))
	results = again.fire_event("actor:57", 9, hit(0x40, 90, 0))
	check(status_of(results, 14186) == "rejected" and status_of(results, 14234) == "ran" and status_of(results, 14414) == "not_reached", "hit 2 (dword_1e 0): 14186 rejected, the exorcism group 14234 runs whole, the death record 14414 not reached (%s)" % [summary(results)])
	check(again.field("actor:57", "byte_0x25") == 5 and again.field(Host.OBJ_22574, "dword_0x15d_added") == 300 and again.field(Host.OBJ_22574, "dword_0x159_added") == 300 and int(again.locals.get(10, -1)) == 1, "14234: +0x25 = 5, +300 into +0x15D and +0x159, local 10 = 1")
	var adapters: Array = []
	for r in results: if int(r.group) == 14234: adapters = r.adapters
	for a in ["opcode2_lock_flags", "opcode2_counters", "opcode2_object_ad", "opcode13_actor_a8", "opcode8_gates"]:
		check(adapters.has(a), "14234 ran on adapter %s (%s)" % [a, adapters])
	# The record's selectors: a hit without bit 0x40 in word0, or with dword_26 above 100, does not admit 14234.
	results = again.fire_event("actor:57", 9, hit(0x20, 90, 0))
	check(status_of(results, 14234) == "rejected" and reason_of(results, 14234).contains("mask"), "a hit without bit 0x0040 in word0 does not admit 14234 (%s)" % reason_of(results, 14234))
	var third = fresh()
	third.fire_event("actor:57", 9, hit(0x20, 200, 30))
	results = third.fire_event("actor:57", 9, hit(0x40, 150, 0))
	check(status_of(results, 14234) == "rejected" and reason_of(results, 14234).contains("dword_26"), "a hit with dword_26 above 100 does not admit 14234 (%s)" % reason_of(results, 14234))
	# Without the fanfix: after hit 1 (+0x25 == 1) predicate 208 (+0x25 == 2) rejects 14234 and the walk goes on.
	plain.fire_event("actor:57", 9, hit(0x20, 200, 30))
	results = plain.fire_event("actor:57", 9, hit(0x40, 90, 0))
	check(status_of(results, 14234) == "rejected" and status_of(results, 14414) != "not_reached", "without the fix 14234 is rejected at +0x25 == 1 (predicate 208): the original bug (%s)" % [summary(results)])
	print("Native host Rix: %d failures" % failures)
	if failures == 0: print("PASS native host rix: fanfix 4882703 208->207 at load; one kind-9 record per hit; hit 1 runs 14102, a hurting hit then runs 14186 whole, the third hit runs the exorcism 14234 whole on adapters; rejected without the fix")
	quit(0 if failures == 0 else 1)
