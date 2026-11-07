extends SceneTree
## Grok backlog 5 item 9 (FABLE_TASK_MAPS_FINISH step 2): the three Act 2/3 exit blockers hosted. L12 region 734 -> level 8 arrival 4
## (opcode 2 arm 0x24, PROVEN body, then the 0x1C level change); L17 movable 50 -> level 16 arrival 2 (opcode 1 on a mode-1 movable:
## adapter opcode1_other_modes, after its kind-6 group 3878 stored +0x25 = 1); L9 prop 104 -> level 8 arrival 5 (the kind-2 timer
## records: control 82's use stores +0x25 = 1, its kind-10 group 14046 stores 2 (kind-10 matcher not entered: run directly, the one
## open link), its kind-5 use starts timer 2140, whose expiry starts timer 2168, whose expiry runs the level change; adapter
## kind2_timer_expiry). The control/prop event callers stay UNKNOWN: the test fires the events with the bytes the records want.
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func verdicts(results: Array) -> Array:
	var out := []
	for r in results: out.append("%d:%s%s" % [int(r.group), str(r.status), "" if r.get("adapters", []).is_empty() else "+A"])
	return out
func reason(results: Array, group: int) -> String:
	for r in results: if int(r.group) == group: return str(r.reasons[0]) if not r.reasons.is_empty() else ""
	return ""
func fresh(area: String) -> RefCounted:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/%s.json" % area).is_empty(), "%s loads" % area)
	host.set_global(0x223D6, 0)
	host.set_global(0x223D4, 0)
	return host
func level(host) -> Array: return [int(host.globals.get(0x223C8, -1)), int(host.globals.get(0x223CC, -1))]
func run() -> void:
	# --- L12_CM region 734: group s0:0 = opcode 2 arm 0x24 (bits 0x10/0x20 of the 0x22574 object's +0x228) + the level change 0x88.
	var host = fresh("L12_CM")
	var r: Array = host.fire_event("region:734", 2)
	check(verdicts(r) == ["0:ran"] and level(host) == [8, 4], "L12 region 734 -> level 8 arrival 4, PROVEN (%s %s)" % [verdicts(r), level(host)])
	check(host.field(Host.OBJ_22574, "bit_0x228_0x10") == 1 and host.field(Host.OBJ_22574, "bit_0x228_0x20") == 1, "arm 0x24 set bits 0x10 and 0x20 of +0x228")
	host.set_adapters_enabled(false)
	host.reset_state(); host.set_global(0x223D6, 0)
	check(verdicts(host.fire_event("region:734", 2)) == ["0:ran"], "arm 0x24 needs no adapter")
	# --- L17_HC movable 50: mode 1 (placement byte +0x22). Group 3878 (kind 6, caller 0x14, predicate 0 = local 0 == 10: the native
	# writer of local 0 is not traced) stores +0x25 = 1 and the travel word 145 (byte 4 = 100); group 3896 (kind 5, caller 4, predicate
	# 207 = +0x25 == 1) then runs 16 commands incl. opcode 1 byte 4 = 0 (travel 0) and the level change 0x50.
	host = fresh("L17_HC")
	r = host.fire_event("movable:50", 6, {"caller_byte": 0x14, "context": "movable:50"})
	check(verdicts(r) == ["3878:unhosted"] and reason(r, 3878).contains("local 0"), "L17 group 3878 waits on predicate 0 (local 0 == 10), not traced (%s)" % [verdicts(r)])
	check(int(host.attributes["movable:50"].mode) == 1 and int(host.attributes["movable:50"].angle_word) == 145, "movable 50 is mode 1 with word +0x4E 145 (placement bytes +0x22 / +0x24)")
	var direct: Dictionary = host.execute_group(1, 3878)
	check(str(direct.status) == "ran" and direct.adapters.has("opcode1_other_modes") and host.field("movable:50", "byte_0x25") == 1 and host.field("movable:50", "travel_0x50") == 145, "group 3878 run directly: +0x25 = 1, travel word 145 = (100 * 145) / 100 on the mode-1 path (%s)" % [direct.get("reasons", [])])
	r = host.fire_event("movable:50", 5, {"caller_byte": 4, "caller_byte_2": 0, "context": "movable:50"})
	check(verdicts(r) == ["3896:ran+A"] and level(host) == [16, 2] and host.field("movable:50", "travel_0x50") == 0, "L17 movable 50 use -> level 16 arrival 2 on adapters, opcode 1 byte 4 = 0 stores travel 0 (%s %s)" % [verdicts(r), reason(r, 3896)])
	var plain = fresh("L17_HC")
	plain.set_adapters_enabled(false)
	plain.set_adapter_enabled("slot_index_binding", true)
	plain.set_field("movable:50", "byte_0x25", 1)
	r = plain.fire_event("movable:50", 5, {"caller_byte": 4, "caller_byte_2": 0, "context": "movable:50"})
	check(verdicts(r) == ["3896:unhosted"] and reason(r, 3896).contains("opcode1_other_modes") == false and reason(r, 3896).contains("opcode"), "with the adapters off 3896 stops at its first adapter-bound command (%s)" % reason(r, 3896))
	# --- L9_DR prop 104: the timer chain.
	host = fresh("L9_DR")
	r = host.fire_event("prop:104", 2)
	check(verdicts(r) == ["2140:rejected", "2168:rejected"] and reason(r, 2140).contains("stopped"), "L9 prop 104's two timers start stopped (byte +5 bit 0) (%s)" % [verdicts(r)])
	r = host.fire_event("control:82", 4, {"arg_c": 0, "context": "control:82"})
	check(verdicts(r) == ["14024:ran+A"] and host.field("control:82", "byte_0x25") == 1, "control 82 use (predicate 206: +0x25 == 0) stores +0x25 = 1 (%s)" % [verdicts(r)])
	r = host.fire_event("control:82", 10, {"context": "control:82"})
	check(verdicts(r) == ["14046:unhosted"] and reason(r, 14046).contains("kind 10"), "control 82's kind-10 record (group 14046, +0x25 = 2) waits on the kind-10 matcher, not entered (%s)" % [verdicts(r)])
	direct = host.execute_group(1, 14046)
	check(str(direct.status) == "ran" and host.field("control:82", "byte_0x25") == 2, "group 14046 run directly stores +0x25 = 2 (the one open link of this chain)")
	r = host.fire_event("control:82", 5, {"caller_byte": 4, "caller_byte_2": 0, "context": "control:82"})
	check(verdicts(r) == ["14058:ran+A"] and r[0].adapters.has("opcode14_timer") and int(host.record_state.get(23241804, {}).get("byte5", -1)) == 0x80, "control 82's kind-5 use (predicate 208: +0x25 == 2) starts prop 104's timer 2140 (byte +5 = 0x80) (%s)" % [verdicts(r)])
	r = host.fire_event("prop:104", 2)
	check(verdicts(r) == ["2140:ran+A", "2168:rejected"] and r[0].adapters.has("kind2_timer_expiry") and int(host.record_state.get(23241804, {}).get("byte5", -1)) == 1 and int(host.record_state.get(23241814, {}).get("byte5", -1)) == 0x80, "timer 2140's expiry runs its group: stops 2140, starts 2168 (count 120) (%s)" % [verdicts(r)])
	r = host.fire_event("prop:104", 2)
	check(verdicts(r) == ["2140:rejected", "2168:ran+A"] and level(host) == [8, 5] and int(host.record_state.get(23241814, {}).get("byte5", -1)) == 1, "timer 2168's expiry stops it and runs the level change: L9 prop 104 -> level 8 arrival 5 (%s %s)" % [verdicts(r), level(host)])
	plain = fresh("L9_DR")
	plain.set_adapter_enabled("kind2_timer_expiry", false)
	r = plain.fire_event("prop:104", 2)
	check(verdicts(r) == ["2140:unhosted", "2168:unhosted"] and reason(r, 2140).contains("kind2_timer_expiry"), "with the adapter off kind-2 events are unhosted")
	print("Act 2 exit blockers: %d failures" % failures)
	if failures == 0: print("PASS act2 exit blockers: L12 region 734 -> L8/4 PROVEN (opcode 2 arm 0x24), L17 movable 50 -> L16/2 (opcode 1 on mode 1 via opcode1_other_modes, after group 3878), L9 prop 104 -> L8/5 through the kind-2 timer chain (kind2_timer_expiry); open: L17 predicate 0 (local 0), L9 kind-10 matcher, the control/prop event callers")
	quit(0 if failures == 0 else 1)
