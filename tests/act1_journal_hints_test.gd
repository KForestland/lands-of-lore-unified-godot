extends SceneTree
## grok M02. The pit note stays quiet on act3's top-of-shaft initial. The river note is the L4 drown flag only.
const Hints = preload("res://scripts/lol2/act1_journal_hints.gd")
const Lift = preload("res://scripts/lol2/hive_elevator_state.gd")
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var bottom := {"hive_elevator": {"played_flute": false, "target": 7, "height": Lift.STOPS[7]}}
	check(Hints.stuck_id(bottom, "pit") == "hive_flute_at_pit", "lift waiting at the bottom")
	var top := {"played_flute": false, "target": 0, "height": -235.0}
	check(Hints.stuck_id({"hive_elevator": top}, "pit") == "", "top of the shaft is not the note")
	var fresh := Lift.initial()
	if int(fresh.target) == 0:
		check(Hints.stuck_id({"hive_elevator": fresh}, "pit") == "", "act3 fresh lift is already at the top")
	else:
		check(int(fresh.target) == 7 and Hints.waiting_at_bottom(fresh), "bottom-stop initial is the r16 lift")
		check(Hints.stuck_id({"hive_elevator": fresh}, "pit") == "hive_flute_at_pit", "r16 fresh lift records the note")
	bottom.hive_elevator.played_flute = true
	check(Hints.stuck_id(bottom, "pit") == "", "flute already played")
	bottom.hive_elevator.played_flute = false
	bottom.hive_elevator.height = -235.0
	check(Hints.stuck_id(bottom, "pit") == "", "target 7 but still at the top height")
	check(Hints.stuck_id({}, "river", {"dead": true}) == "jungle_river_drown", "river drown")
	check(Hints.stuck_id({}, "river", {"dead": false}) == "", "still swimming")
	check(Hints.stuck_id(bottom, "river", {"dead": true}) == "jungle_river_drown", "dead flag is the river note")
	check(Hints.stuck_id({}, "pit", {"dead": true}) == "", "a drown is not the flute note")
	var lip := Vector3(-2305, -203, -7615.5)
	check(Hints.on_pit_lip(lip), "centre of the pit lip")
	check(not Hints.on_pit_lip(Vector3(0, -203, -7615.5)), "off the pit lip")
	for row in Hints.JOURNAL_HINTS:
		check(str(row.hint).length() <= 130, "short %s" % row.when)
		check(MyJournal.hints().has(row.when), "registered %s" % row.when)
	check(MyJournal.hints().size() == 45, "45 notes after M01, M02, and Act 3")
	var hive := Node3D.new()
	Hints.attach(hive, "pit")
	check(hive.get_node_or_null("HivePitJournalHints") != null, "pit attach")
	hive.free()
	var jungle := Node3D.new()
	Hints.attach(jungle, "river")
	check(jungle.get_node_or_null("JungleRiverJournalHints") != null, "river attach")
	jungle.free()
	if failures == 0: print("PASS act1_journal_hints_test: flute note only at the bottom stop, river note on the drown, 45 notes")
	quit(1 if failures else 0)
