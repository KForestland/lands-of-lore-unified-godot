extends Node
## My Journal notes for the L10 tomb oil and the Emperor's door (grok M01, Kimi K18). Text only. Quest state is never
## changed. The hopper quest key is not a note id; that rename lives on the L14 module.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const Oil = preload("res://scripts/lol2/l10_oil.gd")
const Ankh = preload("res://scripts/lol2/l10_ankh_state.gd")
const CATACOMB_HEIGHT := -80.0
const JOURNAL_HINTS := [
	{"when":"l10_fence_tuck","flag":"l10_fences","hint":"A running jump clears the lower rails from the high side. Return by the stairs.","enhanced_guard":"same note in both editions; owner 2026-11-13 ordinary lower-rail jump adapter"},
	{"when":"l10_silverleaf_grows","flag":"l10_silverleaf","hint":"Silverleaf now grows on the cemetery's dead trees. Pick nine and take them to the Wild Village.","enhanced_guard":"same note in both editions"},
	{"when":"l10_tomb_oil","flag":"l10_oil","hint":"The tomb oil will not take a weak spark up close. A stronger spark, or dragon's blood, needs a safe distance.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l10_emperor_door","flag":"l10_priest","hint":"The priest's urn, the chapel ashes, and the ankh are what the Emperor's door is waiting for.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l10_catacomb_braziers","flag":"l10_braziers","hint":"The bone baskets in the dark take a spark. The sword leaves them cold.","enhanced_guard":"same note in both editions (grok OF7)"}]
var host: Node3D

static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l10_journal_hints.gd").new(); n.host = map; n.name = "L10JournalHints"; map.add_child(n); return n

## Open note for a place ("oil", "priest", "slab"), or "". facts: door_shut, urn_missing, ashes_missing, ankh_missing.
static func stuck_id(quests: Dictionary, place: String, facts: Dictionary = {}) -> String:
	if place == "fence": return "l10_fence_tuck"
	var oil: Dictionary = quests.get("l10_oil", {})
	var barrel: Dictionary = quests.get("l10_barrel", {})
	if place == "catacomb": return catacomb_note(float(facts.get("height", 0.0)), bool(facts.get("near_unlit", false)))
	if place == "oil" and not bool(oil.get("burned", false)) and int(barrel.get("phase", 0)) == 2: return "l10_tomb_oil"
	var missing := bool(facts.get("urn_missing", false)) or bool(facts.get("ashes_missing", false)) or bool(facts.get("ankh_missing", false))
	if place in ["priest", "slab"] and bool(facts.get("door_shut", false)) and missing: return "l10_emperor_door"
	return ""

## Underground, and an unlit bone basket within the presenter's note reach.
static func catacomb_note(height: float, near_unlit: bool) -> String:
	if height < CATACOMB_HEIGHT and near_unlit: return "l10_catacomb_braziers"
	return ""

func _door_facts() -> Dictionary:
	var quests: Dictionary = host.quest_state if host.get("quest_state") is Dictionary else {}
	var ankh: Dictionary = quests.get("l10_ankh", Ankh.initial())
	var priest: Dictionary = quests.get("l10_priest", {})
	var carried: Array = host.carried_collected if host.get("carried_collected") is Array else []
	var occupying := str(Ankh.Kit.slot(ankh, Ankh.SLAB).get("occupied", "")) == Ankh.ANKH
	return {
		"door_shut": not Ankh.committed(ankh, Ankh.SLAB),
		"urn_missing": not bool(priest.get("urn_given", false)),
		"ashes_missing": not Ankh.committed(ankh, Ankh.TRADE),
		"ankh_missing": Ankh.ANKH not in carried and not occupying}

func places() -> Array:
	if not is_instance_valid(host) or not is_instance_valid(host.get("player")): return []
	var out: Array = []
	var fences = host.get_node_or_null("L10Fences")
	if fences != null and fences.nearby(): out.append("fence")
	if host.player.global_position.distance_to(Oil.AIM) < Oil.BLAST_RADIUS: out.append("oil")
	out.append("catacomb")
	if not is_instance_valid(host.get("camera")): return out
	var priest = host.get_node_or_null("L10Priest")
	if priest != null and priest.has_method("reachable") and priest.reachable(): out.append("priest")
	var slab = host.get_node_or_null("L10EmperorEntry")
	if slab != null and slab.has_method("reachable") and slab.reachable(): out.append("slab")
	return out

func check() -> String:
	if not is_instance_valid(host) or not host.get("quest_state") is Dictionary: return ""
	if get_tree().paused or host.get("flying"): return ""
	var found := ""
	var facts := _door_facts()
	if is_instance_valid(host.get("player")):
		facts["height"] = host.player.global_position.y
		var braziers: Node = host.get_node_or_null("L10Braziers")
		facts["near_unlit"] = braziers != null and braziers.has_method("near_unlit") and braziers.near_unlit(host.player.global_position)
	for where in places():
		var id := stuck_id(host.quest_state, where, facts)
		if id.is_empty(): continue
		if MyJournal.discover(host, id) and found.is_empty(): found = id
	return found

func _process(_delta: float) -> void:
	check()
