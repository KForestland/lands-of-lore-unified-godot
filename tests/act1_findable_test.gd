extends SceneTree
## Act 1 required path. Hosted journal ids stay registered. This patch adds no note.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const IDS := ["gate_closed_before_shalla", "hive_flute_at_pit", "jungle_river_drown", "long_arm_before_passage", "thohan_sword_broken"]
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
		check(str(hints[id]).length() <= 130, id)
	if failures == 0:
		print("PASS act1 findable: hosted notes stay")
	quit(1 if failures else 0)
