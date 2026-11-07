extends Node
## Act 3 journal notes for six hosted gaps (grok AA04). Text only. Quest state is never changed.
## L16DryFountain is on this base. The L17, L19, and L20 nodes are the unapplied S/T/W/X hosts.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const JOURNAL_HINTS := [
	{"when": "l16_south_fountain", "flag": "l16_dry_fountain", "hint": "The dry fountain is at the south end of the avenue. The ball over it is what I break.", "enhanced_guard": "HINTBOOK (grok AA04). Not shown."},
	{"when": "l17_cavern_exit", "flag": "l17_cavern_run", "hint": "The caverns can be a straight run for the exit. The map shows the heading.", "enhanced_guard": "HINTBOOK (grok AA04). Not shown."},
	{"when": "l19_horn_keep", "flag": "l19_belial_horn", "hint": "Baccata gives me Belial's horn, and then he is gone. I keep the horn.", "enhanced_guard": "HINTBOOK (grok AA04). Not shown."},
	{"when": "l19_sewer_cross", "flag": "l19_sewer_forms", "hint": "As a man I break the bars. As the Lizard I take the gutter. Three switches across the guck raise it.", "enhanced_guard": "HINTBOOK (grok AA04). Not shown."},
	{"when": "l19_ghostly_heads", "flag": "l19_ghostly_heads", "hint": "Four ghostly heads take a level-one mist of doom each. The demon's body goes on the white circle, and I stay out of the fountain.", "enhanced_guard": "HINTBOOK (grok AA04). Not shown."},
	{"when": "l19_curse_mother", "flag": "l19_dawn_curse", "hint": "The curse spell goes in at ancient-magic level five. A purple glob should enter the mother.", "enhanced_guard": "HINTBOOK (grok AA04). Not shown."},
]
const FOUNTAIN_AT := Vector3(440, 85, 10438)
const FOUNTAIN_RADIUS := 800.0
const CAVERN_AT := Vector3(-5436, 32, 5802)
const CAVERN_RADIUS := 160.0
const HORN_AT := Vector3(120, 0, 525)
const HORN_RADIUS := 160.0
const SEWER_AT := Vector3(-323, 30, -2124)
const SEWER_RADIUS := 200.0
const HEADS_AT := [Vector3(1451, -130, -1131), Vector3(1018, -130, -1128), Vector3(1028, -110, -1892), Vector3(1451, -110, -1891)]
const HEADS_RADIUS := 160.0
const DAWN_AT := Vector3(2802, -1000, -882)
const MOTHER_AT := Vector3(-1160, -20, -4258)
const CURSE_RADIUS := 160.0
var host: Node3D

static func attach(map: Node3D) -> Node:
	var node: Node = load("res://scripts/lol2/act3_journal_hints.gd").new()
	var area := str(map.get("area_id"))
	if area != "L16_CA" and area != "L17_HC" and area != "L19_BC" and area != "L20_BB":
		node.free()
		return null
	node.host = map
	node.name = "Act3JournalHints"
	map.add_child(node)
	return node

static func flat_to(pos: Vector3, at: Vector3) -> float:
	return Vector2(pos.x - at.x, pos.z - at.z).length()

static func _ints(raw: Variant) -> int:
	if not raw is Array:
		return 0
	var count := 0
	for item in raw:
		if item is int or item is float:
			var _id := int(item)
			count += 1
	return count

func _open(key: String, field: String) -> bool:
	var quests: Variant = host.get("quest_state")
	if not quests is Dictionary or not quests.has(key):
		return true
	var row: Variant = quests[key]
	if not row is Dictionary:
		return true
	return not bool(row.get(field, false))

func check() -> void:
	if not is_instance_valid(host) or host.get("player") == null:
		return
	var pos: Vector3 = host.player.global_position
	if host.get_node_or_null("L16DryFountain") != null and _open("l16_dry_fountain", "broken") and flat_to(pos, FOUNTAIN_AT) <= FOUNTAIN_RADIUS:
		MyJournal.discover(host, "l16_south_fountain")
	if host.get_node_or_null("L17CavernRun") != null and _exit_open() and flat_to(pos, CAVERN_AT) <= CAVERN_RADIUS:
		MyJournal.discover(host, "l17_cavern_exit")
	if host.get_node_or_null("L19BelialHorn") != null and _open("l19_belial_horn", "taken") and flat_to(pos, HORN_AT) <= HORN_RADIUS:
		MyJournal.discover(host, "l19_horn_keep")
	if host.get_node_or_null("L19SewerForms") != null and _switches() < 3 and flat_to(pos, SEWER_AT) <= SEWER_RADIUS:
		MyJournal.discover(host, "l19_sewer_cross")
	if host.get_node_or_null("L19GhostlyHeads") != null and _shots() < 4 and _nearest_head(pos) <= HEADS_RADIUS:
		MyJournal.discover(host, "l19_ghostly_heads")
	if _curse_open() and _near_curse(pos):
		MyJournal.discover(host, "l19_curse_mother")

func _exit_open() -> bool:
	var quests: Variant = host.get("quest_state")
	if not quests is Dictionary or not quests.has("l17_cavern_run"):
		return true
	var row: Variant = quests["l17_cavern_run"]
	if not row is Dictionary:
		return true
	return int(row.get("exit_region", -1)) < 0

func _switches() -> int:
	var quests: Variant = host.get("quest_state")
	if not quests is Dictionary:
		return 0
	var row: Variant = quests.get("l19_sewer_forms", {})
	if not row is Dictionary:
		return 0
	return _ints(row.get("switches", []))

func _shots() -> int:
	var quests: Variant = host.get("quest_state")
	if not quests is Dictionary:
		return 0
	var row: Variant = quests.get("l19_ghostly_heads", {})
	if not row is Dictionary:
		return 0
	return _ints(row.get("shot", []))

func _nearest_head(pos: Vector3) -> float:
	var nearest := INF
	for at in HEADS_AT:
		nearest = minf(nearest, flat_to(pos, at))
	return nearest

func _curse_open() -> bool:
	var quests: Variant = host.get("quest_state")
	if not quests is Dictionary or not quests.has("l19_dawn_curse"):
		return true
	var row: Variant = quests["l19_dawn_curse"]
	if not row is Dictionary:
		return true
	return not bool(row.get("curse_said", false))

func _near_curse(pos: Vector3) -> bool:
	if host.get_node_or_null("L19DawnCurse") != null and flat_to(pos, DAWN_AT) <= CURSE_RADIUS:
		return true
	if host.get_node_or_null("L20MotherCurse") != null and flat_to(pos, MOTHER_AT) <= CURSE_RADIUS:
		return true
	return false

func _process(_delta: float) -> void:
	check()
