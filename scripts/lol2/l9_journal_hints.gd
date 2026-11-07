extends Node
## My Journal notes for the walking statue and the ruins flood (grok M01, Kimi K18). Text only. Quest state is never
## changed. There is no grate node; the flood note is the drown flag.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const JOURNAL_HINTS := [
	{"when":"l9_statue_human","flag":"l9_statue","hint":"The walking statue keeps me only if I follow as a man. The dampen spell is what holds that shape.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l9_flood_late","flag":"l9_flood","hint":"If I am late for the lifting table, the water wins and I must try the bowl again. At the end I can stand on the grate.","enhanced_guard":"same note in both editions (grok K09)"}]
var host: Node3D

static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l9_journal_hints.gd").new(); n.host = map; n.name = "L9JournalHints"; map.add_child(n); return n

## Places: "alcove", "fight", "flood". facts.form is player_form (0 is human).
static func stuck_id(quests: Dictionary, place: String, facts: Dictionary = {}) -> String:
	var form := int(facts.get("form", 0))
	var walk: Dictionary = quests.get("l9_statue_walk", {})
	if place == "alcove" and form != 0: return "l9_statue_human"
	if place == "fight" and form != 0 and bool(walk.get("arrived", false)) and not bool(walk.get("fight_done", false)): return "l9_statue_human"
	var flood: Dictionary = quests.get("l9_flood", {})
	if place == "flood" and bool(flood.get("dead", false)) and bool(walk.get("fight_done", false)): return "l9_flood_late"
	return ""

func places() -> Array:
	if not is_instance_valid(host) or not is_instance_valid(host.get("player")): return []
	var out: Array = []
	var statue = host.get_node_or_null("L9Statue")
	if statue != null and statue.has_method("in_alcove") and statue.in_alcove(): out.append("alcove")
	var walk: Dictionary = host.quest_state.get("l9_statue_walk", {}) if host.get("quest_state") is Dictionary else {}
	if bool(walk.get("arrived", false)) and not bool(walk.get("fight_done", false)): out.append("fight")
	var flood: Dictionary = host.quest_state.get("l9_flood", {}) if host.get("quest_state") is Dictionary else {}
	if bool(flood.get("dead", false)): out.append("flood")
	return out

func check() -> String:
	if not is_instance_valid(host) or not host.get("quest_state") is Dictionary: return ""
	var facts := {"form": int(host.get("player_form"))}
	var found := ""
	for where in places():
		var id := stuck_id(host.quest_state, where, facts)
		if id.is_empty(): continue
		if MyJournal.discover(host, id) and found.is_empty(): found = id
	return found

func _process(_delta: float) -> void:
	check()
