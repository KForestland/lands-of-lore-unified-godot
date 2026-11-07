extends SceneTree
## Act 2 loop through L13 and L14. The fourteen planner notes stay in their six scripts.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const PATHS := [
	"res://scripts/lol2/l10_journal_hints.gd",
	"res://scripts/lol2/l9_journal_hints.gd",
	"res://scripts/lol2/l8_tribe_dawn_hints.gd",
	"res://scripts/lol2/l13_journal_hints.gd",
	"res://scripts/lol2/l14_journal_hints.gd",
	"res://scripts/lol2/l16_journal_hints.gd",
]
const IDS := [
	"l8_blade_for_daniel", "l8_see_temple_first", "l8_show_guard_blade", "l8_shaman_cemetery_mark",
	"larkhon_must_sleep", "larkhon_join_tribe", "larkhon_ask_shaman", "larkhon_serum_needs_leaf", "larkhon_vapors_unactivated", "l10_tomb_oil", "l10_emperor_door",
	"l9_statue_human", "l9_flood_late", "l10_trees_need_dawn", "l8_not_initiated",
	"l13_citadel_sealed", "l13_dreamstone", "l14_scale_bowls", "l14_boulder_side",
	"l14_hopper_bodies", "l14_chalice",
]
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var hints: Dictionary = MyJournal.hints()
	for id in IDS:
		check(hints.has(id), id)
	var seen := 0
	for path in PATHS:
		var rows: Array = (load(path) as Script).get_script_constant_map()["JOURNAL_HINTS"]
		seen += rows.size()
	check(seen == 14, "fourteen notes in the six Act 2 scripts")
	if failures == 0:
		print("PASS act2 findable: hosted notes stay, fourteen in the six scripts")
	quit(1 if failures else 0)
