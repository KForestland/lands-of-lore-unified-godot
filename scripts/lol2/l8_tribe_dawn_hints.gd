extends Node
## My Journal notes for the tribe initiation and Dawn's bracers (grok M01, Kimi K18). One script, two maps: role
## "tribe" on the Savage Jungle, role "remains" on the cemetery. Each place returns only its own note. Text only.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const Journey = preload("res://scripts/lol2/l8_journey.gd")
const Bracers = preload("res://scripts/lol2/dead_bracers_item.gd")
const JOURNAL_HINTS := [
	{"when":"l8_not_initiated","flag":"l8_tribe","hint":"The tribe's fight, and a silver leaf still in my pack, are what the shaman asks before he calls me one of them.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l10_trees_need_dawn","flag":"l10_silverleaf","hint":"Dawn on the river wants the bracers from the ruins. While I still carry them, the cemetery trees stay dead.","enhanced_guard":"same note in both editions (grok K09)"}]
var host: Node3D
var role := "tribe"

static func attach(map: Node3D, which: String = "tribe") -> Node:
	var n = load("res://scripts/lol2/l8_tribe_dawn_hints.gd").new()
	n.host = map
	n.role = which
	n.name = "L8TribeHints" if which == "tribe" else "L10DawnTreeHints"
	map.add_child(n)
	return n

## Places: "village" (phase idle, admitted, silverleaf grown) and "remains" (trees dead, bracers still carried).
static func stuck_id(quests: Dictionary, place: String, facts: Dictionary = {}) -> String:
	var tribe: Dictionary = quests.get("l8_tribe", {})
	var journey: Dictionary = quests.get("l8_journey", {})
	var trees: Dictionary = quests.get("l10_silverleaf", {})
	if place == "village" and str(tribe.get("phase", "")) == "idle" and bool(journey.get("admitted", false)) and bool(trees.get("grown", false)): return "l8_not_initiated"
	if place == "remains" and not bool(trees.get("grown", false)) and bool(facts.get("bracers", false)): return "l10_trees_need_dawn"
	return ""

func places() -> Array:
	if not is_instance_valid(host) or not is_instance_valid(host.get("player")): return []
	if role == "tribe":
		var translation: Vector3 = host.native_translation if host.get("native_translation") != null else Vector3.ZERO
		var at: Vector3 = Journey.TARGETS.village + translation
		var p: Vector3 = host.player.global_position
		if Vector2(p.x, p.z).distance_to(Vector2(at.x, at.z)) < Journey.REACH: return ["village"]
		return []
	if role == "remains":
		var emperor = host.get_node_or_null("L10Emperor")
		if emperor != null and emperor.has_method("reachable") and emperor.reachable("remains"): return ["remains"]
	return []

func check() -> String:
	if not is_instance_valid(host) or not host.get("quest_state") is Dictionary: return ""
	var facts := {"bracers": false}
	if role == "remains":
		var carried: Array = host.carried_collected if host.get("carried_collected") is Array else []
		facts.bracers = Bracers.available(carried)
	var found := ""
	for where in places():
		var id := stuck_id(host.quest_state, where, facts)
		if id.is_empty(): continue
		if MyJournal.discover(host, id) and found.is_empty(): found = id
	return found

func _process(_delta: float) -> void:
	check()
