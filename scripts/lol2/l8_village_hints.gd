extends Node
## My Journal notes for the L8 village chain before the Larkhon (grok K01/K09, owner r14 playtest 2026-11-05: he reached
## the Larkhon without being admitted and had no way to know why). Each note is recorded once, when Luther is near the
## place where that step happens and the step is still open. Text only; quest state is never changed.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const Journey = preload("res://scripts/lol2/l8_journey.gd")
const NEAR := 420.0
const JOURNAL_HINTS := [
	{"when":"l8_blade_for_daniel","flag":"l8_journey","hint":"Daniel asked for his grandfather's blade. If the gift failed, the knife is still on the ground where we met.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l8_see_temple_first","flag":"l8_journey","hint":"The temple is east of the entry, on the far side of the map. The village stays closed until Luther has been there. A scene plays.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l8_show_guard_blade","flag":"l8_journey","hint":"I have seen the temple. The guard at the great tree wants Daniel's blade before he lets me in.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l8_shaman_cemetery_mark","flag":"l8_journey","hint":"The shaman keeps the mark for the cemetery gate. He trades it only after the guard has let me in.","enhanced_guard":"same note in both editions (grok K09)"}]
var host: Node3D
var elapsed := 0.0

static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l8_village_hints.gd").new(); n.host = map; n.name = "L8VillageHints"; map.add_child(n); return n

## The open step's note id for the journey state at a place ("entry", "temple", "village"), or "".
static func stuck_id(s: Dictionary, place: String) -> String:
	var gift := str(s.get("gift", "unoffered"))
	# Not while Daniel holds the blade ("delivered", before the hoppers knock it away): grok review of 77f63c7.
	if place == "entry" and gift in ["unoffered", "dropped"]: return "l8_blade_for_daniel"
	if place in ["entry", "village"] and gift in ["recovered", "returned"] and not bool(s.get("temple_visited", false)): return "l8_see_temple_first"
	if place in ["temple", "village"] and bool(s.get("temple_visited", false)) and not bool(s.get("admitted", false)): return "l8_show_guard_blade"
	if place == "village" and bool(s.get("admitted", false)) and not bool(s.get("key_awarded", false)): return "l8_shaman_cemetery_mark"
	return ""

func place() -> String:
	if not is_instance_valid(host.get("player")): return ""
	var translation: Vector3 = host.native_translation if host.get("native_translation") != null else Vector3.ZERO
	var p: Vector3 = host.player.global_position
	for id in Journey.TARGETS:
		if Vector2(p.x, p.z).distance_to(Vector2((Journey.TARGETS[id] + translation).x, (Journey.TARGETS[id] + translation).z)) < NEAR: return id
	return ""

func check() -> String:
	var where := place()
	if where.is_empty(): return ""
	var id := stuck_id(host.quest_state.get(Journey.KEY, {}), where)
	if id.is_empty(): return ""
	return id if MyJournal.discover(host, id) else ""

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 1.0: return
	elapsed = 0.0
	var id := check()
	if not id.is_empty() and host.has_method("save_feedback"): host.save_feedback(MyJournal.NOTICE)
