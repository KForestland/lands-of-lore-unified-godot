extends SceneTree
## Load rule census (lead 2026-11-14; scripts/lol2/load_region_rule.gd). Every opcode that appears in a region entry group
## (kind-12 record, event 2) of any staged level must sit on exactly one list - REARM (repeat-safe, re-armed on load) or
## NEVER - so a new opcode fails here and becomes a decision. Then a direct re-arm of L19 region 1943 (entry group 1100:
## opcode 197 arm 10 and the opcode-9 lever press): the 197 runs, the lever press does not, no record write is made.
const Rule = preload("res://scripts/lol2/load_region_rule.gd")
const Host = preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	for op in Rule.REARM: check(not Rule.NEVER.has(op), "opcode %d is on both lists" % op)
	var seen := {}
	var dir := DirAccess.open("res://scripts/lol2/native_scripts/")
	var files: Array = []
	for f in dir.get_files():
		if f.begins_with("L") and f.ends_with(".json"): files.append(f)
	for f in files:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/native_scripts/" + f))
		var groups := {}
		for g in data.groups: groups["%d:%d" % [int(g.stream), int(g.group)]] = g
		for o in data.objects:
			if not str(o.ref).begins_with("region:"): continue
			for e in o.events:
				if e.get("event") == null or int(e.event) != 2 or e.get("group") == null: continue
				var g: Variant = groups.get("%d:%d" % [int(e.stream), int(e.group)])
				if g == null: continue
				for c in g.commands:
					var op := int(c.opcode)
					if not seen.has(op): seen[op] = "%s %s group %d" % [f, str(o.ref), int(e.group)]
	var unlisted: Array = []
	for op in seen:
		if not Rule.REARM.has(op) and not Rule.NEVER.has(op): unlisted.append("%d (first in %s)" % [op, seen[op]])
	check(unlisted.is_empty(), "entry-group opcodes on neither list: %s" % [unlisted])
	print("LOAD RULE census: %d levels, %d distinct entry-group opcodes, REARM %s" % [files.size(), seen.size(), str(Rule.REARM.keys())])
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L19_BC.json").is_empty(), "L19 loads")
	var enqueued := []
	host.connect("event_enqueued", func(ref: String, kind: int, caller: int): enqueued.append(ref))
	var rows: Array = host.rearm_region(1943, Rule.REARM.keys())
	print("LOAD RULE re-arm L19 1943: ", rows, " enqueued ", enqueued)
	check(rows.size() == 1 and int(rows[0].group) == 1100 and int(rows[0].kept) == 1 and int(rows[0].dropped) == 1 and str(rows[0].status) == "ran", "region 1943 re-arm keeps opcode 197 and drops the lever press (%s)" % [rows])
	check(enqueued.is_empty(), "the re-arm enqueued nothing (the lever press stays out) (%s)" % [enqueued])
	# (Grok R118 a) SAVED STATE WINS. L4 region 1654 entry group 3300 sets both bits of record 3805 byte +0x1C (opcode
	# 197 arm 4) when cell 29 is 1; control 82 group 18864 later clears bit 0. A save made after that clear, loaded in
	# region 1654, must keep bit 0 clear: the re-arm may not write a target the save holds.
	# Test aid: cell 29 stored 1 (as controls 85/99/100 and actor 64 do in play). L4 has no native host in the port
	# (Act 1 jungle owners, act2_jungle_return without progression), so this is the host-level proof, not a walk.
	var bit0 := "bit_0x1c_0x01"
	var l4 = Host.new()
	check(l4.load_area("res://scripts/lol2/native_scripts/L4_HJ.json").is_empty(), "L4 loads")
	l4.set_local_e58(29, 1)
	l4.fire_event("region:1654", 2, {})
	var walked: int = int((l4.state.get("0x22d0c:3805", {}) as Dictionary).get(bit0, -1))
	var none: Array[String] = []
	var cleared: Dictionary = l4.call("_run", 1, 18864, none)
	var after_clear: int = int((l4.state.get("0x22d0c:3805", {}) as Dictionary).get(bit0, -1))
	var saved: Dictionary = l4.snapshot()
	var loaded = Host.new()
	check(loaded.load_area("res://scripts/lol2/native_scripts/L4_HJ.json").is_empty() and loaded.restore(saved).is_empty(), "L4 save restores")
	var l4rows: Array = loaded.rearm_region(1654, Rule.REARM.keys())
	var after_load: int = int((loaded.state.get("0x22d0c:3805", {}) as Dictionary).get(bit0, -1))
	print("LOAD RULE L4 1654: walk-in bit0 %d, control 82 (%s) -> %d, F9 re-arm %s -> bit0 %d" % [walked, str(cleared.get("status")), after_clear, str(l4rows), after_load])
	check(walked == 1 and after_clear == 0, "L4 setup: the entry sets bit 0 and control 82 clears it (%d, %d)" % [walked, after_clear])
	check(after_load == 0, "L4 1654: the load keeps the saved clear bit 0 (got %d)" % after_load)
	check(l4rows.size() > 0 and int(l4rows[0].get("saved_skips", 0)) >= 1, "L4 1654: the re-arm reports the skipped write (%s)" % [l4rows])
	# Census: every staged level, every region entry walked once (fresh state, predicate as the host reads it), saved,
	# reloaded and re-armed: how many REARM writes the save now wins.
	var census := {"regions": 0, "rearmed": 0, "kept": 0, "saved_skips": 0}
	for f in files:
		var h = Host.new()
		if not h.load_area("res://scripts/lol2/native_scripts/" + f).is_empty(): continue
		var fresh: Dictionary = h.snapshot()
		var regions := {}
		for ref in h.objects:
			if str(ref).begins_with("region:"): regions[int(str(ref).get_slice(":", 1))] = true
		for r in regions:
			h.restore(fresh)
			h.fire_event("region:%d" % r, 2, {})
			var crows: Array = h.rearm_region(r, Rule.REARM.keys())
			if crows.is_empty(): continue
			census.regions += 1
			for row in crows:
				if row.has("kept"): census.rearmed += 1; census.kept += int(row.kept); census.saved_skips += int(row.get("saved_skips", 0))
	print("LOAD RULE census saved-state-wins: %d regions with an entry, %d re-armed groups, %d REARM commands still written, %d skipped because the save holds the target" % [census.regions, census.rearmed, census.kept, census.saved_skips])
	if failures == 0: print("PASS load region rule: every entry-group opcode in %d levels is on one list; L19 1943 re-arms without its lever press" % files.size())
	quit(1 if failures else 0)
