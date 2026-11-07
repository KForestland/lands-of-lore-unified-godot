extends SceneTree
## grok R02. The three crossing faces stay. The walk picks the closest floor. No hive scene is built.
const Hive = preload("res://scripts/lol2/hive_review.gd")
const Vis = preload("res://scripts/lol2/region_visibility.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Hive.PORTAL_AREA == "L5_HC", "hive portal area")
	check(Hive.ROOF_SKIP == 654, "roof face 654 stays skipped")
	check(Hive.CROSSING_FACES == [1902, 2396, 2379], "crossing faces")
	check(not Hive.drops_crossing_face(1902), "face 1902 stays")
	check(not Hive.drops_crossing_face(2396), "face 2396 stays")
	check(not Hive.drops_crossing_face(2379), "face 2379 stays")
	var nav := [
		[[[0, 0], [10, 0], [10, 10], [0, 10]], 0, 0, []],
		[[[0, 0], [10, 0], [10, 10], [0, 10]], -10, 0, []],
		[[], 0, 0, []],
	]
	check(Vis.region_at_nav(nav, Vector3(5, 1, 5)) == 0, "near floor 0")
	check(Vis.region_at_nav(nav, Vector3(5, -9, 5)) == 1, "near floor -10")
	check(Vis.region_at_nav(nav, Vector3(50, 0, 50)) == -1, "outside the squares")
	check(Vis.region_at_nav([], Vector3(0, 0, 0)) == -1, "empty nav")
	if failures == 0: print("PASS hive_clip_test: faces stay, closest floor")
	quit(1 if failures else 0)
