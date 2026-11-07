extends SceneTree
## grok J03. Face 8631 is the only new skip, and only the constant is asserted here. The draw is the lead's run.
const Review = preload("res://scripts/lol2/jungle_review.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Review.TREE_TOP_SKIP == 8631, "chopped-tree face")
	if failures == 0: print("PASS jungle_tree_top_test: skip face 8631")
	quit(1 if failures else 0)
