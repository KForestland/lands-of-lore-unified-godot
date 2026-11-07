extends SceneTree
## grok M01 / Kimi K18. Fourteen Act 2 journal notes. The hopper when-id is not the quest key.
const L10 = preload("res://scripts/lol2/l10_journal_hints.gd")
const L9 = preload("res://scripts/lol2/l9_journal_hints.gd")
const Tribe = preload("res://scripts/lol2/l8_tribe_dawn_hints.gd")
const L13 = preload("res://scripts/lol2/l13_journal_hints.gd")
const L14 = preload("res://scripts/lol2/l14_journal_hints.gd")
const L16 = preload("res://scripts/lol2/l16_journal_hints.gd")
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const Bowls = preload("res://scripts/lol2/l14_shard_bowls.gd")
const Hopper = preload("res://scripts/lol2/l14_hopper_platform.gd")
const Egg = preload("res://scripts/lol2/l13_egg_door.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var oil := {"l10_oil": {"burned": false}, "l10_barrel": {"phase": 2}}
	check(L10.stuck_id(oil, "oil") == "l10_tomb_oil", "oil near the barrel after the roll")
	oil.l10_oil.burned = true
	check(L10.stuck_id(oil, "oil") == "", "burned oil: no note")
	oil.l10_oil.burned = false
	oil.l10_barrel.phase = 1
	check(L10.stuck_id(oil, "oil") == "", "barrel still rolling: no note")
	var door := {"door_shut": true, "urn_missing": true, "ashes_missing": false, "ankh_missing": false}
	check(L10.stuck_id({}, "priest", door) == "l10_emperor_door", "priest, door shut, urn missing")
	check(L10.stuck_id({}, "slab", {"door_shut": true, "urn_missing": false, "ashes_missing": true, "ankh_missing": false}) == "l10_emperor_door", "slab, ashes missing")
	check(L10.stuck_id({}, "priest", {"door_shut": false, "urn_missing": true}) == "", "door already open")
	check(L10.stuck_id({}, "priest", {"door_shut": true, "urn_missing": false, "ashes_missing": false, "ankh_missing": false}) == "", "door shut but nothing missing")
	check(L10.stuck_id({}, "oil", door) == "", "door facts at the oil are not the door note")
	check(L9.stuck_id({}, "alcove", {"form": 1}) == "l9_statue_human", "beast in the alcove")
	check(L9.stuck_id({}, "alcove", {"form": 0}) == "", "human in the alcove")
	var fight := {"l9_statue_walk": {"arrived": true, "fight_done": false}}
	check(L9.stuck_id(fight, "fight", {"form": 2}) == "l9_statue_human", "lizard at the fight")
	check(L9.stuck_id(fight, "fight", {"form": 0}) == "", "human at the fight")
	fight.l9_statue_walk.fight_done = true
	check(L9.stuck_id(fight, "fight", {"form": 2}) == "", "fight already done")
	var flood := {"l9_flood": {"dead": true}, "l9_statue_walk": {"fight_done": true}}
	check(L9.stuck_id(flood, "flood") == "l9_flood_late", "drowned after the fight")
	flood.l9_statue_walk.fight_done = false
	check(L9.stuck_id(flood, "flood") == "", "drown flag before the fight")
	flood.l9_flood.dead = false
	flood.l9_statue_walk.fight_done = true
	check(L9.stuck_id(flood, "flood") == "", "alive in the flood")
	var tribe := {"l8_tribe": {"phase": "idle"}, "l8_journey": {"admitted": true}, "l10_silverleaf": {"grown": true}}
	check(Tribe.stuck_id(tribe, "village") == "l8_not_initiated", "admitted, trees grown, bout not started")
	tribe.l8_tribe.phase = "fight"
	check(Tribe.stuck_id(tribe, "village") == "", "during the bout")
	tribe.l8_tribe.phase = "idle"
	tribe.l8_journey.admitted = false
	check(Tribe.stuck_id(tribe, "village") == "", "not admitted")
	tribe.l8_journey.admitted = true
	tribe.l10_silverleaf.grown = false
	check(Tribe.stuck_id(tribe, "village") == "", "silverleaf not grown")
	check(Tribe.stuck_id({"l10_silverleaf": {"grown": false}}, "remains", {"bracers": true}) == "l10_trees_need_dawn", "bracers still carried at the remains")
	check(Tribe.stuck_id({"l10_silverleaf": {"grown": true}}, "remains", {"bracers": true}) == "", "trees already grown")
	check(Tribe.stuck_id({"l10_silverleaf": {"grown": false}}, "remains", {"bracers": false}) == "", "bracers already given")
	check(Tribe.stuck_id(tribe, "remains", {"bracers": true}) == "l10_trees_need_dawn", "village state does not block the remains note")
	check(L13.stuck_id({"l13_egg_door": {"opened": false}}, "egg", {"form": 0}) == "l13_citadel_sealed", "human at the sealed globe")
	check(L13.stuck_id({"l13_egg_door": {"opened": false}}, "egg", {"form": 1}) == "", "beast at the globe")
	check(L13.stuck_id({"l13_egg_door": {"opened": true}}, "egg", {"form": 0}) == "", "globe already open")
	check(L13.at_globe(Egg.AIM, Egg.AIM), "on the spark sphere")
	check(not L13.at_globe(Egg.AIM + Vector3(0, 40, 0), Egg.AIM + Vector3(80, 0, 0)), "outside the spark sphere")
	check(L13.stuck_id({}, "exit", {"can_leave": false}) == "l13_dreamstone", "exit lock closed")
	check(L13.stuck_id({}, "temple", {"can_leave": false}) == "l13_dreamstone", "temple lock closed")
	check(L13.stuck_id({}, "exit", {"can_leave": true}) == "", "exit already open")
	check(L13.stuck_id({}, "egg", {"can_leave": false, "form": 1}) == "", "a closed lock is not the globe note")
	check(L14.stuck_id({}, "bowls", {"shard": true}) == "l14_scale_bowls", "shard carried, bowls open")
	var full := Bowls.initial()
	full.slots = {"405": {"occupied": Bowls.SHARDS[0], "committed": true, "receipts": ["405"]}, "406": {"occupied": Bowls.SHARDS[1], "committed": true, "receipts": ["406"]}}
	check(L14.stuck_id({"l14_shard_bowls": full}, "bowls", {"shard": true}) == "", "both bowls committed")
	check(L14.stuck_id({}, "bowls", {"shard": false}) == "", "no shard carried")
	check(L14.in_boulder_box(Vector3(29, 182, 1136)), "centre of the kill box")
	check(not L14.in_boulder_box(Vector3(29 + 80, 182, 1136)), "outside the kill box")
	var trap := {"l14_trap_route": {"triggered": true, "elapsed": 1.0}}
	check(L14.stuck_id(trap, "boulder") == "l14_boulder_side", "boulder in the kill window")
	trap.l14_trap_route.elapsed = 0.2
	check(L14.stuck_id(trap, "boulder") == "", "boulder not yet in the window")
	trap.l14_trap_route.elapsed = 1.7
	check(L14.stuck_id(trap, "boulder") == "", "boulder past the window")
	trap.l14_trap_route.triggered = false
	trap.l14_trap_route.elapsed = 1.0
	check(L14.stuck_id(trap, "boulder") == "", "boulder not triggered")
	check(L14.stuck_id({}, "hopper") == "l14_hopper_bodies", "platform not complete")
	var bodies := Hopper.initial()
	for id in Hopper.IDS: bodies.slots[id] = {"occupied": Hopper.item(id), "committed": true, "receipts": [id]}
	check(L14.stuck_id({"l14_hopper_platform": bodies}, "hopper") == "", "five bodies committed")
	var hopper_row: Dictionary = {}
	for row in L14.JOURNAL_HINTS:
		if row.flag == "l14_hopper_platform": hopper_row = row
	check(hopper_row.when == "l14_hopper_bodies" and hopper_row.when != "l14_hopper_platform", "hopper note id is not the quest key")
	var chalice := {"stone": true, "belial_dead": true}
	check(L14.stuck_id({"l14_chamber_voices": {"offered": false}}, "chalice", chalice) == "l14_chalice", "Belial dead, stone carried, not offered")
	check(L14.stuck_id({"l14_chamber_voices": {"offered": true}}, "chalice", chalice) == "", "already offered")
	check(L14.stuck_id({"l14_chamber_voices": {"offered": false}}, "chalice", {"stone": true, "belial_dead": false}) == "", "Belial still alive")
	check(L14.stuck_id({"l14_chamber_voices": {"offered": false}}, "chalice", {"stone": false, "belial_dead": true}) == "", "no Dreamstone")
	check(L16.stuck_id({"l16_greenhouse": {"silverleaf": "", "opened": false}}, "hourglass") == "l16_hourglass_leaf", "empty pyramid at the hourglass")
	check(L16.stuck_id({"l16_greenhouse": {"silverleaf": "", "opened": false}}, "plate") == "l16_hourglass_leaf", "empty pyramid at the plate")
	check(L16.stuck_id({"l16_greenhouse": {"silverleaf": "act2:leaf", "opened": false}}, "hourglass") == "", "leaf already set")
	check(L16.stuck_id({"l16_greenhouse": {"silverleaf": "act2:leaf", "opened": true}}, "tower") == "l16_one_tower", "this tower's doors are open")
	check(L16.stuck_id({"l16_greenhouse": {"opened": false}}, "tower") == "", "tower still shut")
	check(L16.stuck_id({"l16_greenhouse": {"silverleaf": "", "opened": true}}, "hourglass") == "l16_hourglass_leaf", "open tower does not replace the leaf note")
	var seen := {}
	for script in [L10, L9, Tribe, L13, L14, L16]:
		var map := Node3D.new()
		if script == Tribe: script.attach(map, "tribe"); check(map.get_node_or_null("L8TribeHints") != null, "tribe attach")
		elif script == L13: script.attach(map, "citadel"); check(map.get_node_or_null("L13JournalHints") != null, "citadel attach")
		else: script.attach(map); check(map.get_child_count() == 1, "attach adds one child")
		for row in script.JOURNAL_HINTS:
			check(str(row.hint).length() <= 130 and str(row.hint).length() >= 20, "short note %s" % row.when)
			check(MyJournal.hints().has(row.when), "registered %s" % row.when)
			check(not seen.has(row.when), "unique %s" % row.when)
			seen[row.when] = true
		map.free()
	var temple := Node3D.new()
	L13.attach(temple, "temple")
	check(temple.get_node_or_null("L8TempleJournalHints") != null, "temple role attach")
	temple.free()
	var dawn := Node3D.new()
	Tribe.attach(dawn, "remains")
	check(dawn.get_node_or_null("L10DawnTreeHints") != null, "remains role attach")
	dawn.free()
	check(seen.size() == 14, "fourteen notes")
	check(not MyJournal.hints().has("l14_hopper_platform"), "quest key is not a journal id")
	if failures == 0: print("PASS act2_journal_hints_test: 14 M01 notes, hopper id l14_hopper_bodies, registered once")
	quit(1 if failures else 0)
