extends SceneTree
## Headless MOFF office lifecycle: first visit, source revisits and exit counters,
## rune visit, translation exit, translated revisit and the delayed once-only orb.
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
const State = preload("res://scripts/lol2/monastery_quest_state.gd")
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: "+label)
func roundtrip(state: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(state))
func enter(s: Dictionary) -> String:
	s.room = "MOFF"
	Speech.begin(s,"MOFF")
	return s.conversation.sequence if Speech.active(s.conversation) else ""
func finish(s: Dictionary) -> Array:
	return Speech.advance(s,10000.0)
## Room layer equivalent: exit sequences return to MENT when they finish.
func leave(s: Dictionary) -> String:
	if not Speech.begin_moff_exit(s): return ""
	var name: String = s.conversation.sequence
	return name
func _run() -> void:
	var s := State.initial()
	s.locals.Met_Dawn = 1
	check(State.office_admitted(s),"office not admitted after Dawn")
	check(enter(s) == "MOFF" and s.flags["134"] == 1,"first visit")
	check(finish(s) == [Speech.FLUTE] and s.flags["136"] == 1 and s.flags["138"] == 1,"first visit flute")
	check(leave(s) == "MOFF_EXIT_FIRST" and s.flags["145"] == 1,"first exit 384-385")
	check(State.validate(roundtrip(s)).is_empty(),"mid first exit invalid")
	finish(s)
	check(enter(s) == "MOFF_REVISIT","second visit 400-406")
	finish(s)
	check(leave(s) == "MOFF_EXIT_SECOND" and s.flags["146"] == 1,"second exit 407-412")
	finish(s)
	check(enter(s) == "MOFF_REVISIT_LATE","third visit 450-453")
	finish(s)
	check(leave(s) == "MOFF_EXIT_LATER" and s.flags["264"] == 1,"third exit 407")
	finish(s)
	check(not State.office_admitted(s),"MENT rune gate should close the office after flag264")
	# Copied runes reopen it; message9 plays 500-505, then the existing rune offer runs.
	s.globals.GV_HAS_RUNES = 1
	check(State.office_admitted(s) and enter(s) == "MOFF_HELD_RUNES" and s.moff_load.translated == 0,"rune visit")
	finish(s)
	for key in ["140","141","142","283"]: s.flags[key] = 1
	s.globals.GV_RUNES_TRANSLATED = 1 # As MOFF_RUNES completes in-room.
	check(leave(s) == "MOFF_EXIT_RUNES","translation-visit exit 506-507 (translated after load)")
	check(State.validate(roundtrip(s)).is_empty(),"mid rune exit invalid")
	check(finish(s) == [] and s.globals.GV_KNOWLEDGE_OF_POWER_ORB == 0 and s.flags["148"] == 0,"no orb on the translation visit")
	# The next visit sees translated=1 at load: 600-604 then flag288.
	check(State.office_admitted(s) and enter(s) == "MOFF_TRANSLATED" and s.moff_load.translated == 1,"translated revisit")
	Speech.advance(s,Speech.duration("MOFF_TRANSLATED",0)+0.1)
	check(State.validate(roundtrip(s)).is_empty() and s.flags["288"] == 0,"mid translated revisit")
	finish(s)
	check(s.flags["288"] == 1 and not State.office_admitted(s),"flag288 closes further office entry")
	check(leave(s) == "MOFF_EXIT_ORB" and s.flags["148"] == 1 and s.globals.GV_KNOWLEDGE_OF_POWER_ORB == 0,"orb exit starts, grant still pending")
	var before := 0.0
	for index in range(2): before += Speech.duration("MOFF_EXIT_ORB",index)
	Speech.advance(s,before+0.2)
	var saved := roundtrip(s) # Partial line566.
	check(State.validate(saved).is_empty() and int(saved.conversation.cursor) == 2,"mid line566 save")
	var grants := Speech.advance(s,Speech.duration("MOFF_EXIT_ORB",2))
	check(grants == [Speech.ORB] and s.globals.GV_KNOWLEDGE_OF_POWER_ORB == 1 and int(s.globals.GV_LUTHERS_SOUL) == 1 and Speech.active(s.conversation),"grant after 566 before 567")
	check(finish(s) == [] and not Speech.active(s.conversation),"line567 and no second grant")
	check(Speech.advance(saved,10000.0) == [Speech.ORB],"restored partial exit grants exactly once")
	check(not Speech.begin_moff_exit(saved) or saved.conversation.sequence != "MOFF_EXIT_ORB","repeat exit gave another orb")
	# Invalid saved states.
	var bad := roundtrip(s)
	bad.conversation = {"sequence":"MOFF_EXIT_ORB","cursor":3,"elapsed":0.0}
	bad.globals.GV_KNOWLEDGE_OF_POWER_ORB = 0
	check(not State.validate(bad).is_empty(),"orb exit past line566 without knowledge accepted")
	bad = roundtrip(s)
	bad.conversation = {"sequence":"MOFF_EXIT_ORB","cursor":0,"elapsed":0.0}
	bad.flags["148"] = 0
	check(not State.validate(bad).is_empty(),"orb exit without flag148 accepted")
	bad = roundtrip(s)
	bad.pending_items = ["monastery:item94:Iron_Flute"]
	check(not State.validate(bad).is_empty(),"foreign pending item accepted")
	# Older saves: no office flags, snapshot, soul or pending list.
	var legacy := State.initial()
	for key in State.OFFICE_FLAGS: legacy.flags.erase(key)
	legacy.globals.erase("GV_LUTHERS_SOUL")
	legacy.locals.Met_Dawn = 1
	legacy.flags["134"] = 1
	legacy.flags["136"] = 1
	legacy.room = "MOFF"
	legacy.globals.GV_HAS_RUNES = 1
	legacy.globals.GV_RUNES_TRANSLATED = 1
	legacy.flags["283"] = 1
	legacy = roundtrip(legacy)
	check(State.validate(legacy).is_empty(),"legacy save rejected")
	check(leave(legacy) == "MOFF_EXIT_RUNES" and legacy.moff_load.translated == 0 and State.validate(roundtrip(legacy)).is_empty(),"legacy in-office save exits via 506-507")
	finish(legacy)
	legacy.room = "MOFF"
	Speech.begin(legacy,"MOFF")
	check(legacy.conversation.sequence == "MOFF_TRANSLATED","legacy save reaches the delayed orb visit")
	if failures:
		push_error("FAIL: %d MOFF lifecycle checks" % failures)
		quit(1)
		return
	print("PASS: MOFF first visit, revisits/counters, rune visit, 506-507 translation exit, 600-604/288 revisit, delayed once-only orb grant, partial saves and legacy saves")
	quit()
