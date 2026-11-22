extends Node
## My Journal notes for the walking statue and the ruins flood (grok M01, Kimi K18). Text only. Quest state is never
## changed. There is no grate node; the flood note is the drown flag.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
## G3: region 2306 in Godot x,z, from creature_nav/L9_DR. Y is the floor-200 stand (232) with room to jump.
const MIRROR_MIN: Vector3 = Vector3(-3081.0, 160.0, -8281.0)
const MIRROR_MAX: Vector3 = Vector3(-2972.0, 320.0, -8175.0)
const JOURNAL_HINTS := [
	{"when":"l9_rotten_rail","flag":"l9_noble_rails","hint":"The rail is rotten; a blow would break it.","enhanced_guard":"same note in both editions; BJ14 F6 owner rule"},
	{"when":"l9_flood_table","flag":"l9_flood","hint":"The water is rising. The table by the low roof floats.","enhanced_guard":"same note in both editions; BJ14 F6 owner rule"},
	{"when":"l9_statue_human","flag":"l9_statue","hint":"The walking statue keeps me only if I follow as a man. The dampen spell is what holds that shape.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l9_flood_late","flag":"l9_flood","hint":"If I am late for the lifting table, the water wins and I must try the bowl again. At the end I can stand on the grate.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l9_mirror_jungle","flag":"l9_mirror","hint":"One of these mirrors leads back to the jungle.","enhanced_guard":"same note in both editions (grok G3)"}]
var host: Node3D

static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l9_journal_hints.gd").new(); n.host = map; n.name = "L9JournalHints"; map.add_child(n); return n

## Places: "alcove", "fight", "flood", "rail", "rising", "mirror". facts.form is player_form (0 is human).
static func in_mirror_room(at: Vector3) -> bool:
	return at.x >= MIRROR_MIN.x and at.x <= MIRROR_MAX.x and at.y >= MIRROR_MIN.y and at.y <= MIRROR_MAX.y and at.z >= MIRROR_MIN.z and at.z <= MIRROR_MAX.z

static func stuck_id(quests: Dictionary, place: String, facts: Dictionary = {}) -> String:
	if place == "mirror": return "l9_mirror_jungle"
	if place == "rail": return "l9_rotten_rail"
	if place == "rising" and bool(quests.get("l9_statue_walk", {}).get("fight_done", false)) and not bool(quests.get("l9_escape", {}).get("escaped", false)) and not bool(quests.get("l9_flood", {}).get("dead", false)): return "l9_flood_table"
	var form := int(facts.get("form", 0))
	var walk: Dictionary = quests.get("l9_statue_walk", {})
	if place == "alcove" and form != 0: return "l9_statue_human"
	if place == "fight" and form != 0 and bool(walk.get("arrived", false)) and not bool(walk.get("fight_done", false)): return "l9_statue_human"
	var flood: Dictionary = quests.get("l9_flood", {})
	if place == "flood" and bool(flood.get("dead", false)) and bool(walk.get("fight_done", false)): return "l9_flood_late"
	return ""

func _body() -> Vector3:
	var at: Vector3 = host.player.global_position
	var shift: Variant = host.get("native_translation")
	if shift is Vector3:
		at = at - (shift as Vector3)
	return at

func places() -> Array:
	if not is_instance_valid(host) or not is_instance_valid(host.get("player")): return []
	var out: Array = []
	if in_mirror_room(_body()): out.append("mirror")
	var rails = host.get_node_or_null("L9NobleRails")
	if rails != null and rails.nearby(): out.append("rail")
	var statue = host.get_node_or_null("L9Statue")
	if statue != null and statue.has_method("in_alcove") and statue.in_alcove(): out.append("alcove")
	var walk: Dictionary = host.quest_state.get("l9_statue_walk", {}) if host.get("quest_state") is Dictionary else {}
	if bool(walk.get("arrived", false)) and not bool(walk.get("fight_done", false)): out.append("fight")
	var flood: Dictionary = host.quest_state.get("l9_flood", {}) if host.get("quest_state") is Dictionary else {}
	if bool(flood.get("dead", false)): out.append("flood")
	var water = host.get_node_or_null("L9Flood")
	if water != null and water.enabled(): out.append("rising")
	return out

func check() -> String:
	if not is_instance_valid(host) or not host.get("quest_state") is Dictionary: return ""
	if get_tree().paused or host.get("flying"): return ""
	var facts := {"form": int(host.get("player_form"))}
	var found := ""
	for where in places():
		var id := stuck_id(host.quest_state, where, facts)
		if id.is_empty(): continue
		if MyJournal.discover(host, id) and found.is_empty(): found = id
	return found

func _process(_delta: float) -> void:
	check()
