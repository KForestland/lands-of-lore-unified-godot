extends Node
## My Journal notes for the sealed citadel and the Dreamstone locks (grok M01, Kimi K18). Role "citadel" is the egg
## globe and the Hive exit. Role "temple" is the Savage Jungle temple door, the same note's second hook. Text only.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const Egg = preload("res://scripts/lol2/l13_egg_door.gd")
const JOURNAL_HINTS := [
	{"when":"l13_citadel_sealed","flag":"l13_egg_door","hint":"Something in the citadel is still sealed. A charged globe, then the upper halls, stand between me and the stone.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l13_dreamstone","flag":"l13_exit_lock","hint":"The Dreamstone is past the Hive Lord. Dawn's lock and the temple door both take it, and both give it back.","enhanced_guard":"same note in both editions (grok K09)"}]
var host: Node3D
var role := "citadel"

static func attach(map: Node3D, which: String = "citadel") -> Node:
	var n = load("res://scripts/lol2/l13_journal_hints.gd").new()
	n.host = map
	n.role = which
	n.name = "L13JournalHints" if which == "citadel" else "L8TempleJournalHints"
	map.add_child(n)
	return n

## The globe reach is the spark sphere of radius 24. There is no walk radius on the egg door.
static func at_globe(body: Vector3, camera: Vector3) -> bool:
	return body.distance_to(Egg.AIM) <= 24.0 or camera.distance_to(Egg.AIM) <= 24.0

## Places: "egg" (opened false, human), "exit" and "temple" (that lock's can_leave is false).
static func stuck_id(quests: Dictionary, place: String, facts: Dictionary = {}) -> String:
	var egg: Dictionary = quests.get("l13_egg_door", {})
	if place == "egg" and not bool(egg.get("opened", false)) and int(facts.get("form", 0)) == 0: return "l13_citadel_sealed"
	if place in ["exit", "temple"] and not bool(facts.get("can_leave", true)): return "l13_dreamstone"
	return ""

func _lock_closed(node_name: String) -> bool:
	var node = host.get_node_or_null(node_name)
	if node == null or not node.has_method("can_leave"): return false
	return not node.can_leave()

func places() -> Array:
	if not is_instance_valid(host) or not is_instance_valid(host.get("player")): return []
	if role == "temple":
		var door = host.get_node_or_null("L8TempleDoor")
		if door != null and door.has_method("reachable") and door.reachable() and _lock_closed("L8TempleDoor"): return ["temple"]
		return []
	var out: Array = []
	var camera: Vector3 = host.camera.global_position if is_instance_valid(host.get("camera")) else host.player.global_position
	if at_globe(host.player.global_position, camera): out.append("egg")
	var lock = host.get_node_or_null("L13ExitLock")
	if lock != null and lock.has_method("reachable") and lock.reachable() and _lock_closed("L13ExitLock"): out.append("exit")
	return out

func check() -> String:
	if not is_instance_valid(host) or not host.get("quest_state") is Dictionary: return ""
	var facts := {"form": int(host.get("player_form")), "can_leave": false}
	var found := ""
	for where in places():
		var id := stuck_id(host.quest_state, where, facts)
		if id.is_empty(): continue
		if MyJournal.discover(host, id) and found.is_empty(): found = id
	return found

func _process(_delta: float) -> void:
	check()
