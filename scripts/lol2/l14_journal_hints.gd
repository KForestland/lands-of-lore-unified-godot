extends Node
## My Journal notes for the Huline Temple scale, boulder, hoppers, and chalice (grok M01, Kimi K18). The hopper note
## id is l14_hopper_bodies. The quest key stays l14_hopper_platform. Text only. Quest state is never changed.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const Bowls = preload("res://scripts/lol2/l14_shard_bowls.gd")
const Hopper = preload("res://scripts/lol2/l14_hopper_platform.gd")
const JOURNAL_HINTS := [
	{"when":"l14_scale_bowls","flag":"l14_shard_bowls","hint":"The scale in the temple wants both crystal shards, one in each bowl, before the way behind it opens.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l14_boulder_side","flag":"l14_trap_route","hint":"The boulder in the centre of that hall kills. The safe way is the strip along the side.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l14_hopper_bodies","flag":"l14_hopper_platform","hint":"Five hopper bodies belong on the wooden platform. My own weight is not enough to make it rise.","enhanced_guard":"same note in both editions (grok K09)"},
	{"when":"l14_chalice","flag":"l14_chamber_voices","hint":"The Chamber of Voices takes the Dreamstone into the chalice, and the stone does not come back.","enhanced_guard":"same note in both editions (grok K09)"}]
var host: Node3D

static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l14_journal_hints.gd").new(); n.host = map; n.name = "L14JournalHints"; map.add_child(n); return n

## Kill box from l14_trap_route: abs(x-29)<62, abs(z-1136)<55, feet y-32 in [130, 180].
static func in_boulder_box(p: Vector3) -> bool:
	var feet := p.y - 32.0
	return absf(p.x - 29.0) < 62.0 and absf(p.z - 1136.0) < 55.0 and feet >= 130.0 and feet <= 180.0

## facts: shard, stone, belial_dead. The boulder place still needs triggered and elapsed in [0.75, 1.5].
static func stuck_id(quests: Dictionary, place: String, facts: Dictionary = {}) -> String:
	if place == "bowls" and not Bowls.complete(quests.get("l14_shard_bowls", Bowls.initial())) and bool(facts.get("shard", false)): return "l14_scale_bowls"
	var trap: Dictionary = quests.get("l14_trap_route", {})
	var elapsed := float(trap.get("elapsed", 0.0))
	if place == "boulder" and bool(trap.get("triggered", false)) and elapsed >= 0.75 and elapsed <= 1.5: return "l14_boulder_side"
	if place == "hopper" and not Hopper.complete(quests.get("l14_hopper_platform", Hopper.initial())): return "l14_hopper_bodies"
	var voices: Dictionary = quests.get("l14_chamber_voices", {})
	if place == "chalice" and not bool(voices.get("offered", false)) and bool(facts.get("stone", false)) and bool(facts.get("belial_dead", false)): return "l14_chalice"
	return ""

func _facts() -> Dictionary:
	var carried: Array = host.carried_collected if host.get("carried_collected") is Array else []
	var shard := false
	for id in Bowls.SHARDS:
		if id in carried: shard = true
	var voices = host.get_node_or_null("L14ChamberVoices")
	var stone: bool = voices != null and voices.has_method("carried_dreamstone") and not voices.carried_dreamstone().is_empty()
	var belial: bool = voices != null and voices.has_method("belial_dead") and voices.belial_dead()
	return {"shard": shard, "stone": stone, "belial_dead": belial}

func places() -> Array:
	if not is_instance_valid(host) or not is_instance_valid(host.get("player")): return []
	var out: Array = []
	var bowls = host.get_node_or_null("L14ShardBowls")
	if bowls != null and bowls.has_method("reach") and (bowls.reach("405") or bowls.reach("406")): out.append("bowls")
	# l14_trap_route compares host.player.position, not global_position.
	if in_boulder_box(host.player.position): out.append("boulder")
	var hopper = host.get_node_or_null("L14HopperPlatform")
	if hopper != null and is_instance_valid(host.get("camera")):
		var delta: Vector3 = Hopper.POINT - host.camera.global_position
		if delta.length() > 0.01 and delta.length() < 145.0 and (-host.camera.global_basis.z).dot(delta.normalized()) > 0.86: out.append("hopper")
	var voices = host.get_node_or_null("L14ChamberVoices")
	if voices != null and voices.has_method("door_in_reach") and voices.door_in_reach(): out.append("chalice")
	return out

func check() -> String:
	if not is_instance_valid(host) or not host.get("quest_state") is Dictionary: return ""
	var facts := _facts()
	var found := ""
	for where in places():
		var id := stuck_id(host.quest_state, where, facts)
		if id.is_empty(): continue
		if MyJournal.discover(host, id) and found.is_empty(): found = id
	return found

func _process(_delta: float) -> void:
	check()
