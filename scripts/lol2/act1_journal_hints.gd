extends Node
## My Journal notes for the Hive pit flute and the Jungle river (grok M02). No other Act 1 beat had a hint sentence.
## Text only. Quest state is never changed. Role "pit" is the Hive. Role "river" is L4_HJ only.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const Lift = preload("res://scripts/lol2/hive_elevator_state.gd")
const Elevator = preload("res://scripts/lol2/hive_elevator.gd")
const JOURNAL_HINTS := [
	{"when":"hive_flute_at_pit","flag":"hive_elevator","hint":"The lift waits at the bottom of the pit. The iron flute calls it up.","enhanced_guard":"same note in both editions (grok M02)"},
	{"when":"jungle_river_drown","flag":"","hint":"The big river by the land bridge pulls me under if I stay in it. The bank is the way across.","enhanced_guard":"same note in both editions (grok M02)"}]
var host: Node3D
var role := "pit"

static func attach(map: Node3D, which: String) -> Node:
	var n = load("res://scripts/lol2/act1_journal_hints.gd").new()
	n.host = map
	n.role = which
	n.name = "HivePitJournalHints" if which == "pit" else "JungleRiverJournalHints"
	map.add_child(n)
	return n

## The lip polygon is hive_elevator.gd PIT_LIP (trigger 282 when the hall trigger was missed).
static func on_pit_lip(position: Vector3) -> bool:
	if absf(position.y - 32.0 - Elevator.PIT_LIP_FLOOR) > 48.0: return false
	return Geometry2D.is_point_in_polygon(Vector2(position.x, position.z), PackedVector2Array(Elevator.PIT_LIP))

## Waiting at the bottom stop. act3 initial() is height -235 and target 0, so this is false on a fresh act3 game.
## r16 initial() is already STOPS[7] / target 7, so the same test is true there before the flute.
static func waiting_at_bottom(lift: Dictionary) -> bool:
	if bool(lift.get("played_flute", false)): return false
	if int(lift.get("target", -1)) != 7: return false
	return absf(float(lift.get("height", 0.0)) - float(Lift.STOPS[7])) <= 1.0

static func stuck_id(quests: Dictionary, place: String, facts: Dictionary = {}) -> String:
	if place == "pit" and waiting_at_bottom(quests.get("hive_elevator", {})): return "hive_flute_at_pit"
	if place == "river" and bool(facts.get("dead", false)): return "jungle_river_drown"
	return ""

func check() -> String:
	if not is_instance_valid(host): return ""
	var found := ""
	if role == "pit":
		var elevator = host.get_node_or_null("Elevator")
		if elevator == null or not is_instance_valid(host.get("player")): return ""
		if elevator.trigger_at_player() != 282: return ""
		var id := stuck_id({"hive_elevator": elevator.checkpoint}, "pit", {})
		if not id.is_empty() and MyJournal.discover(host, id): found = id
		return found
	var liquid = host.get("liquid_drowning")
	if liquid == null or not is_instance_valid(liquid) or str(liquid.get("area")) != "L4_HJ": return ""
	if not bool(liquid.drowning.dead): return ""
	var id := stuck_id({}, "river", {"dead": true})
	if not id.is_empty() and MyJournal.discover(host, id): found = id
	return found

func _process(_delta: float) -> void:
	check()
