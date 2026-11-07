extends SceneTree
const Wall = preload("res://scripts/lol2/l17_beast_blade.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Wall.STRAND_ID == -1 and Wall.FROND_ID == -1, "no strand or frond row")
	check(Wall.SCENE_NAME == "hw01.vqa" and not Wall.IN_MOVIE_TABLE, "scene name stays off the movie table")
	check(Wall.nearest_gap() == 4158507, "nearest file gap")
	check(Wall.EXIT_COMMAND_OFFSET - Wall.HW12_OFFSET > Wall.nearest_gap(), "hw12 is farther")
	check(Wall.EXIT_COMMAND_OFFSET - Wall.HW14_OFFSET > Wall.nearest_gap(), "hw14 is farther")
	check(Wall.EXIT_COMMAND_OFFSET - Wall.HW01_EARLIER > Wall.nearest_gap(), "the earlier hw01 copy is farther")
	check(not Wall.plays_movie() and not Wall.relocates_player(), "no playback and no move")
	check(Wall.validate(Wall.initial()).is_empty(), "initial state")
	var bad: Dictionary = Wall.initial()
	bad.erase("cut")
	check(not Wall.validate(bad).is_empty(), "a short state is refused")
	if failures == 0: print("PASS l17_beast_blade_test: hw01.vqa is the nearest stored name and is not played")
	quit(1 if failures else 0)
