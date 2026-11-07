extends SceneTree
const Atlas = preload("res://scripts/lol2/atlas_explored.gd")
const Quest = preload("res://scripts/lol2/act_one_quest_state.gd")
var failures: int = 0

class Host:
	extends Node3D
	var quest_state: Dictionary = {}
	var atlas_explored = null
	var area_id := "L14_HT"
	var player: Node3D
	var progression: Node
	var region_visibility: Node
	var geometry_file := ""

class Progress:
	extends Node
	var current_region := 4

class Sight:
	extends Node
	var visible_regions := {4: true, 9: true}

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func stop(node: Node, code: int) -> void:
	if is_instance_valid(node):
		node.queue_free()
		await process_frame
	quit(code)

func run() -> void:
	var fresh: Dictionary = Quest.initial()
	var empty: Dictionary = Atlas.initial()
	check(not fresh.has("atlas_explored") and empty.areas.is_empty() and Atlas.validate(empty, {}).is_empty(), "a new game starts empty")
	check(Quest.validate(fresh).is_empty(), "initial quests validate")
	var revealed: Dictionary = Atlas.reveal(empty, "L14_HT", [4, 4, -1, 9])
	check(revealed.areas.L14_HT.regions.size() == 2 and int(revealed.areas.L14_HT.regions[0]) == 4 and int(revealed.areas.L14_HT.regions[1]) == 9 and not revealed.areas.L14_HT.full, "visit and sight union")
	var old: Dictionary = fresh.duplicate(true)
	old["act2_creatures_L8_SJ"] = {}
	var migrated: Dictionary = Atlas.migrate(old, "L14_HT")
	check(migrated.areas.L14_HT.full and migrated.areas.L8_SJ.full and migrated.areas.L14_HT.regions.is_empty(), "an old save reveals visited areas")
	check(Atlas.read_error({"quests": old}).is_empty() and Atlas.taken({"quests": old}, "L14_HT").areas.L8_SJ.full, "a save without the key migrates on load")
	var moved: Dictionary = {"quests": {"atlas_explored": empty.duplicate(true)}, "atlas_explored": empty.duplicate(true)}
	check(Atlas.read_error(moved).is_empty() and Atlas.taken(moved, "L14_HT").areas.is_empty(), "the top-level key wins and the old quests key still validates")
	var stayed: Dictionary = Atlas.reveal(migrated, "L14_HT", [3])
	check(stayed.areas.L14_HT.full and stayed.areas.L14_HT.regions.is_empty(), "a full area stays a flag")
	var done: Dictionary = Atlas.reveal(Atlas.initial(), "L4_HJ", [2, 0, 1], 3)
	check(done.areas.L4_HJ.full, "a finished area collapses")
	var bad: Dictionary = {"version": 1, "areas": {"L14_HT": {"full": true, "regions": [1]}}}
	check(not Atlas.validate(bad, {}).is_empty() and not Atlas.read_error({"atlas_explored": bad}).is_empty(), "full with a region list is refused")
	var host := Host.new()
	host.player = Node3D.new()
	host.add_child(host.player)
	host.progression = Progress.new()
	host.region_visibility = Sight.new()
	host.quest_state = Quest.initial()
	host.atlas_explored = Atlas.initial()
	root.add_child(host)
	var tracker: Node = Atlas.attach(host)
	tracker.set_process(false)
	var before: Dictionary = host.quest_state.duplicate(true)
	tracker.note()
	var saved: Dictionary = host.atlas_explored
	var row: Dictionary = saved.areas.L14_HT
	check(row.regions.size() == 2 and int(row.regions[0]) == 4 and int(row.regions[1]) == 9 and not row.full, "the tracker records the stood region and the visible set")
	check(host.quest_state == before and not host.quest_state.has("atlas_explored"), "walking leaves quests unchanged")
	host.atlas_explored = null
	host.quest_state["atlas_explored"] = Atlas.initial()
	tracker.note()
	var moved_field: Dictionary = host.atlas_explored
	check(not host.quest_state.has("atlas_explored") and moved_field.areas.L14_HT.regions.size() == 2, "note moves the old quests key out")
	host.atlas_explored = null
	tracker.note()
	var migrated_field: Dictionary = host.atlas_explored
	check(migrated_field.areas.L14_HT.full and not host.quest_state.has("atlas_explored"), "a missing host field migrates on the next note")
	check(Atlas.area_of(host) == "L14_HT", "area id wins")
	if failures == 0: print("PASS atlas explored: visit, sight, and old saves")
	await stop(host, 1 if failures else 0)
