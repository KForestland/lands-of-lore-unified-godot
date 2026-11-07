extends SceneTree
## Owner r14 playtest 2026-11-05 (at the Larkhon, never admitted) + grok K01/K09: the L8 village chain notes.
const Hints = preload("res://scripts/lol2/l8_village_hints.gd")
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var s := {"version":1,"gift":"unoffered","temple_visited":false,"admitted":false,"key_awarded":false}
	check(Hints.stuck_id(s, "entry") == "l8_blade_for_daniel", "unoffered gift at the meeting place")
	s.gift = "delivered"
	check(Hints.stuck_id(s, "entry") == "", "Daniel holds the blade: no dropped-blade note (grok review)")
	s.gift = "dropped"
	check(Hints.stuck_id(s, "entry") == "l8_blade_for_daniel", "dropped blade at the meeting place")
	s.gift = "recovered"
	check(Hints.stuck_id(s, "village") == "l8_see_temple_first", "owner state: blade recovered, temple not seen")
	var temple_note := ""
	for row in Hints.JOURNAL_HINTS:
		if row.when == "l8_see_temple_first": temple_note = str(row.hint)
	check(temple_note.contains("east of the entry") and temple_note.contains("far side of the map") and temple_note.contains("stays closed") and temple_note.contains("scene plays"), "temple note names the far side, the closed village, and the scene")
	check(temple_note.length() <= 130, "temple note stays within the journal length")
	check(Hints.stuck_id(s, "temple") == "", "at the temple before visiting: no note")
	s.temple_visited = true
	check(Hints.stuck_id(s, "village") == "l8_show_guard_blade", "temple seen, not admitted")
	s.admitted = true
	check(Hints.stuck_id(s, "village") == "l8_shaman_cemetery_mark", "admitted, no key")
	s.key_awarded = true
	check(Hints.stuck_id(s, "village") == "", "chain done: no note")
	for row in Hints.JOURNAL_HINTS:
		check(MyJournal.hints().has(row.when) and str(row.hint).length() <= 130, "note %s registered and short" % row.when)
	# Production host: the owner's save shape at the village gate records the temple note once.
	var scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	scene.quest_state["l8_journey"] = {"version":1,"gift":"recovered","temple_visited":false,"admitted":false,"key_awarded":false}
	var hints = scene.get_node("L8VillageHints")
	var translation: Vector3 = scene.native_translation if scene.get("native_translation") != null else Vector3.ZERO
	scene.player.global_position = preload("res://scripts/lol2/l8_journey.gd").TARGETS.village + translation
	check(hints.check() == "l8_see_temple_first", "village gate records the temple note")
	check(hints.check() == "", "recorded once")
	check("l8_see_temple_first" in MyJournal.notes(scene), "note is in My Journal")
	if failures == 0: print("PASS l8_village_hints_test: four village-chain notes, owner state -> see the temple first, once, in My Journal")
	quit(1 if failures else 0)
