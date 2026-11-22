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
	{"when":"l8_shaman_cemetery_mark","flag":"l8_journey","hint":"The shaman keeps the mark for the cemetery gate. He trades it only after the guard has let me in.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l8_guard_wants_blade_back","flag":"l8_journey","hint":"The village guard wants Daniel's blade in my hand. Daniel is at the west entry: offer it, then pick it up when he drops it.","enhanced_guard":"same note in both editions (BJ12)"},
	{"when":"l8_cemetery_gate_east","flag":"l10_main_gate","hint":"The shaman wants Silverleaf. His sigil opens the Dracoid Cemetery, east of the village; the dead there must be appeased.","enhanced_guard":"same note in both editions (BJ12)"},
	{"when":"l8_leaves_for_the_tribe","flag":"l8_tribe","hint":"Silverleaf: one presented in the Wild Village begins the initiation, another buys the shaman's potion.","enhanced_guard":"same note in both editions (BJ12)"}]
var host: Node3D
var elapsed := 0.0

static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l8_village_hints.gd").new(); n.host = map; n.name = "L8VillageHints"; map.add_child(n); return n

## The open step's note id for the journey state at a place ("entry", "temple", "village"), or "".
static func stuck_id(s: Dictionary, place: String) -> String:
	var gift := str(s.get("gift", "unoffered"))
	# Not while Daniel holds the blade ("delivered", before the hoppers knock it away): grok review of 77f63c7.
	if place == "entry" and gift in ["unoffered", "dropped"]: return "l8_blade_for_daniel"
	if place == "village" and gift in ["unoffered", "delivered", "dropped"] and not bool(s.get("admitted", false)): return "l8_guard_wants_blade_back"
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

## Notes that do not wait for a place (BJ12): the way to the cemetery once the sigil is carried, what the leaves are for,
## and the serum's mix as soon as the serum is in the pack (it used to appear only beside the Larkhon).
func carried_note() -> String:
	var quests: Dictionary = host.quest_state
	var journey: Dictionary = quests.get(Journey.KEY, {})
	var Items = preload("res://scripts/lol2/act2_items_catalog.gd")
	var carried: Array = host.carried_collected if host.get("carried_collected") is Array else []
	if bool(journey.get("key_awarded", false)) and not bool(quests.get("l10_main_gate", {}).get("open", false)) and MyJournal.discover(host, "l8_cemetery_gate_east"): return "l8_cemetery_gate_east"
	if carried.any(func(id): return Items.definition(id) == 117) and not preload("res://scripts/lol2/l8_shaman_trade.gd").completed(quests.get("l8_shaman_trade", {})) and MyJournal.discover(host, "l8_leaves_for_the_tribe"): return "l8_leaves_for_the_tribe"
	if carried.any(func(id): return Items.definition(id) == 119) and MyJournal.discover(host, "larkhon_serum_needs_leaf"): return "larkhon_serum_needs_leaf"
	var Guardian = preload("res://scripts/lol2/l8_larkhon_state.gd")
	var dose: Dictionary = quests.get(Guardian.KEY, Guardian.initial())
	if Guardian.mixed(dose) and not Guardian.used(dose) and MyJournal.discover(host, "larkhon_vapors_unactivated"): return "larkhon_vapors_unactivated"
	return ""

func check() -> String:
	var early := carried_note()
	if not early.is_empty(): return early
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
