extends SceneTree
## grok J06. Ceiling 654 is the skip. The gate is the hive pack only. Floors are not in this list.
const Hive = preload("res://scripts/lol2/hive_review.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Hive.ROOF_SKIP == 654, "ceiling face")
	check(Hive.skips_roof("res://assets/lol2/generated/hive_review/hive.json"), "hive pack")
	check(not Hive.skips_roof("res://assets/lol2/generated/jungle_review/jungle.json"), "jungle pack is not this skip")
	check(not [655, 662, 663, 670].has(Hive.ROOF_SKIP), "the brick floors stay")
	if failures == 0: print("PASS hive_roof_test: skip hive face 654 only")
	quit(1 if failures else 0)
