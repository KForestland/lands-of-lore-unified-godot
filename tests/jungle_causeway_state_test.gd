extends SceneTree
## Owner r12e report 5 (the causeway at 5529,-3715 is not destroyed after the Bacatta tour): every exit ending runs
## op9 prop4648 property21, whose g17352 sinks the causeway. Before, g17352 was not staged and the event20 vanished.
## Source closure: every staged event20 call reaches a staged group; each ending queues g17352 once (local43 = 1), and
## nothing before an ending does.
const State = preload("res://scripts/lol2/jungle_exit_encounter_state.gd")
const POST := {"shared": {"13": 0, "14": 1, "18": 1, "47": 0}, "locals": {"41": 0, "49": 0, "51": 0}}
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_causeway_state: ", message); quit(1)

func ctx() -> Dictionary: return POST.merged({"opcode8": func(_c): return true})

func run() -> void:
	var src: Dictionary = State.source()
	var staged := {}
	for g in src.groups: staged["%s:%d:%d:%d" % [g.owner_kind, int(g.owner), int(g.record), int(g.value) & 255]] = true
	for g in src.groups:
		for c in g.commands:
			var b: PackedByteArray = str(c).hex_decode()
			if b[0] == 9 and b[4] == 21:
				var kind: String = {2: "actor", 3: "prop"}.get(b[1], "?")
				if not staged.has("%s:%d:6:20" % [kind, b[2] | (b[3] << 8)]): return fail("Group %d calls an unstaged event20 (%s)" % [int(g.group), c])
	if State.group_row(src, 17352).is_empty(): return fail("Causeway group 17352 not staged")
	# Nothing before an ending queues the causeway: regions, guard spawn, timers.
	var early: Dictionary = State.initial(src)
	var effects: Array = []
	for region in [4437, 4435, 4439, 4442]: effects.append_array(State.enter_region(early, src, region, ctx()))
	effects.append_array(State.spawn_guards(early, src, ctx()))
	effects.append_array(State.advance(early, src, 1.0, ctx()))
	for e in effects:
		if str(e.type) == "group" and int(e.group) == 17352: return fail("Causeway queued before an ending")
	# The three endings: predicate50 (local48 >= 3), 51 (local48 < 3, prop4398 state0), 52 (state1).
	var cases := [[3, 0, 16986, "HW-BRDGE.VQA"], [0, 0, 17076, "E068E.VQA"], [0, 1, 17160, "E069E.VQA"]]
	for row in cases:
		var s: Dictionary = State.initial(src)
		s.locals["48"] = row[0]
		s.prop4398 = row[1]
		var e: Array = State._dispatch(s, src, "prop", 4398, 6, 20, ctx())
		var groups: Array = e.filter(func(x): return str(x.type) == "group").map(func(x): return int(x.group))
		if groups != [row[2], 17352]: return fail("Ending %d queued %s" % [row[2], groups])
		if e.any(func(x): return str(x.type) == "unstaged_event"): return fail("Ending %d reported an unstaged event" % row[2])
		if not e.any(func(x): return str(x.type) == "local" and int(x.local) == 43 and int(x.value) == 1): return fail("Ending %d did not set local43" % row[2])
		if str(s.ending.movie) != row[3]: return fail("Ending %d movie %s" % [row[2], s.ending.movie])
		# The causeway runs after the ending group's own commands (FIFO), including its movie request.
		var movie := e.find(e.filter(func(x): return str(x.type) == "movie")[0])
		var local43 := e.find(e.filter(func(x): return str(x.type) == "local" and int(x.local) == 43)[0])
		if movie < 0 or local43 < movie: return fail("Ending %d order differs" % row[2])
	print("PASS jungle_causeway_state: event20 closure over %d staged groups; endings 16986/17076/17160 each queue g17352 (local43=1) after their movie request; nothing earlier does" % src.groups.size())
	quit(0)
