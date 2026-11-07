extends SceneTree
const Wall = preload("res://scripts/lol2/l19_beast_wall.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Wall.STRAND_ID == -1 and Wall.FROND_ID == -1, "no strand or frond row")
	check(Wall.MOVIE == -1 and Wall.ARRIVAL_SELECTOR == -1, "no movie and no arrival")
	check(not Wall.plays_movie() and not Wall.relocates_player(), "no playback and no move")
	check(Wall.validate(Wall.initial()).is_empty(), "initial state")
	var bad: Dictionary = Wall.initial()
	bad.erase("noted")
	check(not Wall.validate(bad).is_empty(), "a short state is refused")
	if failures == 0: print("PASS l19_beast_wall_test: strands, movie, and arrival stay unbound")
	quit(1 if failures else 0)
