extends SceneTree
## Museum Sk-key locks: source contract for all 17 controls, single-key conservation, SS1 panel and save validation.
const State = preload("res://scripts/lol2/museum_key_locks_state.gd")
const Save = preload("res://scripts/lol2/museum_save.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Names = preload("res://scripts/lol2/act_one_item_names.gd")
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true
		push_error(message)
		quit(1)
	return ok
func inv(collected: Array, hand := "") -> Dictionary: return {"collected":collected,"hand":hand}
func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/museum_key_locks_source.json"))
	# Source contract per lock: one exact-key mode3 consuming the held item, one mode0 granting one key.
	if not check(source.locks.size() == 17 and source.sconces.size() == 23, "Source lock/sconce counts"): return
	var grant := "03010000330a8b17"
	for id in State.LOCKS:
		var lock: Dictionary = source.locks[str(id)]
		if not check(int(lock.insert.mode) == 3 and int(lock.insert.held_identity) == 394988083 and "020100001800" in lock.insert.commands, "Insert record for %d" % id): return
		if not check(int(lock.take.mode) == 0 and lock.take.commands.filter(func(c): return c.begins_with(grant)).size() == 1, "Take record for %d" % id): return
		if not check(bool(lock.initial_loaded) == (id == 87), "Initial load for %d" % id): return
	if not check(Names.source_name(State.KEY) == "92-Sk key" and Names.source_name(State.SS1) == "68-SS1", "Source names"): return
	if not check(Catalog.admitted(State.KEY, "museum") and Catalog.admitted(State.SS1, "jungle") and not Catalog.admitted(State.KEY, "cave"), "Catalog scopes"): return
	# Initial: the key is in control87 only.
	var s := State.initial()
	if not check(State.validate(s, []).is_empty() and not State.validate(s, [State.KEY]).is_empty(), "Initial conservation"): return
	for id in State.LOCKS:
		if not check(State.group(s, id, "") == ("take" if id == 87 else ""), "Initial group %d" % id): return
	# Take from 87, then every lock: insert from hand, refusals, take back into the hand.
	var bag := inv([])
	if not check(State.run(s, 87, bag) == ["take", 87] and bag.collected == [State.KEY] and bag.hand == State.KEY, "Take control87"): return
	var lines := 0
	for id in State.LOCKS:
		if not check(State.run(s, id, inv(bag.collected.duplicate(), "")).is_empty(), "Insert without held key %d" % id): return
		if not check(State.run(s, id, bag) == ["insert", id] and bag.collected.is_empty() and bag.hand == "" and s.loaded == [id], "Insert %d" % id): return
		if not check(State.validate(s, bag.collected).is_empty(), "Valid after insert %d" % id): return
		for other in State.LOCKS:
			if other != id and not check(State.group(s, other, "") == "", "Empty lock %d offers a key while %d is loaded" % [other, id]): return
		if not check(State.run(s, id, inv([], "museum:item11:Fine_Longsword")).is_empty(), "Take with a busy hand %d" % id): return
		if not check(State.run(s, id, bag) == ["take", id] and bag.collected == [State.KEY] and s.loaded.is_empty(), "Take %d" % id): return
		lines += 1
	# Derived targets.
	State.run(s, 113, bag)
	if not check(State.sconces_lit(s) and not State.panel_lowered(s) and not State.gallery_open(s), "control113 lights sconces"): return
	State.run(s, 113, bag); State.run(s, 140, bag)
	if not check(State.gallery_open(s) and not State.sconces_lit(s), "control140 opens gallery"): return
	State.run(s, 140, bag)
	# Panel: reachable only while lock114 is loaded; give/put back SS1 exactly once.
	if not check(State.run_panel(s, inv([], "")) == "", "Panel closed without lock114"): return
	State.run(s, 114, bag)
	var bag2 := inv(bag.collected, "")
	if not check(State.run_panel(s, bag2) == "give" and bag2.collected == [State.SS1] and bag2.hand == State.SS1 and int(s.panel_state) == 1, "Give SS1"): return
	if not check(State.validate(s, bag2.collected).is_empty() and not State.validate(s, []).is_empty(), "SS1 consistency"): return
	if not check(State.run_panel(s, inv(bag2.collected.duplicate(), "")) == "", "Second SS1 refused"): return
	if not check(State.run_panel(s, bag2) == "put_back" and bag2.collected.is_empty() and int(s.panel_state) == 0, "Return SS1"): return
	# Validation negatives and JSON round trip.
	var round: Dictionary = JSON.parse_string(JSON.stringify({"version":1,"loaded":[140],"panel_state":1}, "", true, true))
	if not check(State.validate(round, [State.SS1]).is_empty() and State.canonical(round).loaded == [140], "JSON round trip"): return
	for bad in [{"version":1,"loaded":[140,141],"panel_state":0}, {"version":1,"loaded":[99],"panel_state":0}, {"version":1,"loaded":[1.5],"panel_state":0},
			{"version":2,"loaded":[],"panel_state":0}, {"version":1,"loaded":[],"panel_state":2}, {"version":1,"loaded":[]}, []]:
		if not check(not State.validate(bad, [State.KEY]).is_empty(), "Accepted %s" % [bad]): return
	if not check(not State.validate({"version":1,"loaded":[140],"panel_state":0}, [State.KEY]).is_empty(), "Duplicate key accepted"): return
	if not check(not State.validate({"version":1,"loaded":[],"panel_state":0}, []).is_empty(), "Lost key accepted"): return
	# Museum save: legacy saves (no field) may not carry the key; new saves are checked against carried items.
	var save := {"format":Save.FORMAT,"version":1,"player":{"position":[0,0,0],"yaw":0,"pitch":0},
		"checkpoint":{"version":1,"introduction_complete":true,"collected":[],"equipped_item":"","sword":{"started":false,"collected":false,"elapsed":0},"gate":{"target_open":false,"progress":0}}}
	if not check(Save.validate(save).is_empty(), "Base save rejected: " + Save.validate(save)): return
	save.checkpoint.collected = [State.KEY]
	if not check(not Save.validate(save).is_empty(), "Legacy save with key accepted"): return
	save.checkpoint.museum_key_locks = {"version":1,"loaded":[],"panel_state":0}
	if not check(Save.validate(save).is_empty(), "Carried key save rejected: " + Save.validate(save)): return
	save.checkpoint.museum_key_locks = {"version":1,"loaded":[140],"panel_state":0}
	if not check(not Save.validate(save).is_empty(), "Duplicated key save accepted"): return
	save.checkpoint.collected = []
	save.checkpoint.gallery = {"painting_moved":false,"lever_pulled":false,"gate_open":true,"progress":1}
	if not check(Save.validate(save).is_empty(), "Lock140 open grate rejected: " + Save.validate(save)): return
	save.checkpoint.museum_key_locks = {"version":1,"loaded":[141],"panel_state":0}
	if not check(not Save.validate(save).is_empty(), "Open grate without lever or lock140 accepted"): return
	save.checkpoint.gallery = {"painting_moved":true,"lever_pulled":false,"gate_open":false,"progress":0.4}
	if not check(Save.validate(save).is_empty(), "Closing grate after lock140 take rejected: " + Save.validate(save)): return
	save.checkpoint.erase("museum_key_locks")
	if not check(not Save.validate(save).is_empty(), "Legacy closing grate without lever accepted"): return
	print("PASS museum_key_locks_state: 17 source locks (exact-key mode3 consume, mode0 one-key grant), only control87 preloaded; insert/refuse/take through all 17 (%d); single-key conservation, sconce/gallery/panel targets, SS1 once, validation and museum save negatives." % lines)
	quit()
