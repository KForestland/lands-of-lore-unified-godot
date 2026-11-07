extends SceneTree
## grok R05. L16, L19, and L20 join the list. Hive and Jungle stay off it. No map is built.
const Map = preload("res://scripts/lol2/act2_map.gd")
const Jungle = preload("res://scripts/lol2/jungle_walkthrough.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var areas: Array = Map.PORTAL_VISIBILITY_AREAS
	var kept: bool = "L14_HT" in areas and "L10_DC" in areas and "L9_DR" in areas
	var added: bool = "L16_CA" in areas and "L19_BC" in areas and "L20_BB" in areas
	var hive_off: bool = not ("L5_HC" in areas)
	var jungle_off: bool = not ("L4_HJ" in areas)
	var off_const: bool = hive_off and jungle_off
	check(kept, "the three hosts stay")
	check(added, "city, Belial, finale")
	check(off_const, "hive and jungle stay off the const")
	check(Jungle.PORTAL_AREA == "L4_HJ", "jungle area id")
	if failures == 0: print("PASS portal_areas_test: L16 L19 L20, jungle L4_HJ")
	quit(1 if failures else 0)
