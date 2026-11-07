extends SceneTree
## grok J09. The two jungle lips clip away. A lower wall does not. Another pack is not clipped.
const Review = preload("res://scripts/lol2/jungle_review.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var review = Review.new()
	check(review._lip_top(10239) == 104.0, "face 10239 clips at 104")
	check(review._lip_top(9929) == 64.0, "face 9929 clips at 64")
	check(review._lip_top(8631) < 0.0, "the tree-top face is not a lip")
	var lip := {"points": [[0, 104, 0], [8, 104, 0], [8, 127, 0], [0, 127, 0]]}
	check(review._clipped(lip, review._lip_top(10239)).is_empty(), "a lip that starts at the ceiling is dropped")
	var below := {"points": [[0, 0, 0], [8, 0, 0], [8, 40, 0], [0, 40, 0]]}
	check(not review._clipped(below, 104.0).is_empty(), "a wall below the cut stays")
	review.geometry_file = "res://assets/lol2/generated/jungle_review/hive.json"
	check(review._lip_top(10239) < 0.0 and review._lip_top(9929) < 0.0, "hive geometry is not these two lips")
	review.free()
	if failures == 0: print("PASS jungle_sky_lip_test: faces 10239 and 9929 clip, and only on jungle.json")
	quit(1 if failures else 0)
