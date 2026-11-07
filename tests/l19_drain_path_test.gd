extends SceneTree
const Path = preload("res://scripts/lol2/l19_drain_path.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Path.DRAIN_SWITCHES == [50, 71, 72] and Path.BRIDGE == 70, "drain switch ids")
	# Rule changed 2026-11-07 (book 5442, Kimi K30): the door click opens the Golden Doors.
	check(Path.DOORS == [51, 52] and Path.moves_doors() and not Path.drain_required(), "the door click opens the doors and the drain stays optional")
	check(Path.WALK.size() == 3 and Path.WALK[0][0] == 2557.0 and Path.WALK[2][0] == 2621.5 and Path.WALK[2][1] == -883.5, "nav prefix")
	check(Path.validate(Path.initial()).is_empty(), "initial state")
	var bad: Dictionary = Path.initial()
	bad.drain_switches = [50, 99]
	check(not Path.validate(bad).is_empty(), "an unknown switch is refused")
	if failures == 0: print("PASS l19_drain_path_test: optional drain, doors 51 and 52, region 1943 branch")
	quit(1 if failures else 0)
