extends Node
## My Journal notes for the Ancient City hourglass and the one open tower (grok M01, Kimi K18). The other three
## towers are not fields in l16_greenhouse.gd and are not invented here. Text only. Quest state is never changed.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const Greenhouse = preload("res://scripts/lol2/l16_greenhouse.gd")
const JOURNAL_HINTS := [
	{"when":"l16_hourglass_leaf","flag":"l16_greenhouse","hint":"If the hourglass only chimes, the glass pyramid still wants a silver leaf.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l16_one_tower","flag":"l16_greenhouse","hint":"One tower is open. The other three, and a box that fits a disk, are still between me and the centre.","enhanced_guard":"same note in both editions (grok K09)"}]
var host: Node3D

static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l16_journal_hints.gd").new(); n.host = map; n.name = "L16JournalHints"; map.add_child(n); return n

## "hourglass" and "plate" need an empty silverleaf. "tower" is the frame opened becomes true. No walk radius was read
## for the other towers, so the open-tower note is the saved flag on this map.
static func stuck_id(quests: Dictionary, place: String, _facts: Dictionary = {}) -> String:
	var green: Dictionary = quests.get("l16_greenhouse", {})
	if place in ["hourglass", "plate"] and str(green.get("silverleaf", "")) == "": return "l16_hourglass_leaf"
	if place == "tower" and bool(green.get("opened", false)): return "l16_one_tower"
	return ""

func places() -> Array:
	if not is_instance_valid(host): return []
	var out: Array = []
	var green = host.get_node_or_null("L16Greenhouse")
	if green != null and green.has_method("aimed"):
		if green.aimed(Greenhouse.HOURGLASS, 130.0): out.append("hourglass")
		if green.aimed(Greenhouse.PLATE, 150.0): out.append("plate")
	var state: Dictionary = host.quest_state.get("l16_greenhouse", {}) if host.get("quest_state") is Dictionary else {}
	if bool(state.get("opened", false)): out.append("tower")
	return out

func check() -> String:
	if not is_instance_valid(host) or not host.get("quest_state") is Dictionary: return ""
	var found := ""
	for where in places():
		var id := stuck_id(host.quest_state, where, {})
		if id.is_empty(): continue
		if MyJournal.discover(host, id) and found.is_empty(): found = id
	return found

func _process(_delta: float) -> void:
	check()
