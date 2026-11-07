extends SceneTree
## Headless: My Journal (my_journal.gd). The 45 stuck-point notes are read from the planners' JOURNAL_HINTS; a note is
## recorded once, at its moment, into the carried item_effects packet; older saves have none; malformed journals are
## rejected; the page shows only discovered note text (never the developer guard text); the Museum pilot flame records
## its note only for a Spark before the plate.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const ItemState = preload("res://scripts/lol2/player_item_state.gd")
const Continuity = preload("res://scripts/lol2/player_continuity.gd")
const Torches = preload("res://scripts/lol2/museum_torches.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

class Effects extends Node:
	var data: Dictionary = preload("res://scripts/lol2/player_item_state.gd").initial()
	func state() -> Dictionary: return data

class Host extends Node3D:
	var feedback: Array = []
	var item_effects: Node
	func save_feedback(text: String) -> void: feedback.append(text)

func run() -> void:
	var hints: Dictionary = MyJournal.hints()
	check(hints.size() == 45, "45 notes from the planners (%d)" % hints.size())
	check(hints.values().all(func(t): return str(t).length() >= 20), "every note has text")
	# Old saves and validation.
	check(not ItemState.initial().has("journal"), "a new game starts with no notes")
	check(MyJournal.validate(null).is_empty(), "older saves without a journal load")
	check(MyJournal.validate(["stones", "tavern_after_farewell"]).is_empty(), "known unique notes are valid")
	check(not MyJournal.validate(["stones", "stones"]).is_empty(), "duplicate note refused")
	check(not MyJournal.validate(["no_such_note"]).is_empty(), "unknown note refused")
	check(not MyJournal.validate([3]).is_empty(), "non-text note refused")
	check(not MyJournal.validate("stones").is_empty(), "non-list journal refused")
	var saved := ItemState.initial()
	saved.journal = ["stones"]
	check(ItemState.validate(saved).is_empty(), "item_effects with a journal is valid")
	check(ItemState.canonical(saved).get("journal") == ["stones"], "canonical keeps the journal")
	saved.journal = ["stones", "stones"]
	check(not ItemState.validate(saved).is_empty(), "item_effects rejects a malformed journal")
	check(ItemState.canonical(ItemState.initial()).has("journal") == false, "canonical adds no journal to old saves")
	# Discovery on a host with the shared item_effects owner.
	var host := Host.new()
	var effects := Effects.new()
	host.item_effects = effects
	host.add_child(effects)
	root.add_child(host)
	check(MyJournal.notes(host).is_empty() and MyJournal.page_text([]) == MyJournal.EMPTY, "empty journal page")
	check(MyJournal.discover(host, "stones") and MyJournal.notes(host) == ["stones"], "first discovery records the note")
	check(not MyJournal.discover(host, "stones") and MyJournal.notes(host).size() == 1, "no duplicate note")
	check(host.feedback == [MyJournal.NOTICE], "one notice per new note")
	var page := MyJournal.page_text(MyJournal.notes(host))
	check(page.find(str(hints.stones)) >= 0 and page.find("guard") == -1 and page.find("Enhanced") == -1, "page shows the note, never the guard text")
	check(ItemState.validate(effects.data).is_empty(), "the live packet stays valid")
	var snapshot := Continuity.from_packet({"item_effects": effects.data}, {})
	check(snapshot.get("journal[stones]") == 1, "continuity snapshot carries the journal")
	# Museum pilot flame: the note comes from a Spark before the plate only.
	var t: Node3D = Torches.new()
	host.add_child(t)
	var error: String = t.setup(host, null)
	check(error.is_empty(), "torch setup: " + error)
	if error.is_empty():
		t.receive_hit("61", 0x2, 1, Torches.SPARK_DAMAGE)
		check(not "pilot_spark_before_plate" in MyJournal.notes(host), "a non-fire hit records nothing")
		t.receive_hit("61", 1, 1, Torches.SPARK_DAMAGE)
		check("pilot_spark_before_plate" in MyJournal.notes(host), "Spark before the plate records the note")
		t.state.pilot_state = 1
		t.receive_hit("61", 1, 1, Torches.SPARK_DAMAGE)
		check(t.state.pilot_spent and MyJournal.notes(host).count("pilot_spark_before_plate") == 1, "the switch still works; the note is not repeated")
	host.queue_free()
	if failures:
		push_error("FAIL: %d My Journal checks" % failures)
		quit(1)
		return
	print("PASS My Journal: 45 notes, recorded once at their moment, saved in item_effects, old saves empty, malformed rejected, page shows text only, pilot note only before the plate")
	quit()
