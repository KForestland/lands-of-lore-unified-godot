extends SceneTree
const Run = preload("res://scripts/lol2/l17_cavern_run.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Run.decode(Run.FORWARD_BYTE) == Vector2i(19, 1), "0x33 is level 19 arrival 1")
	check(Run.decode(Run.CIRCLE_BYTE) == Vector2i(16, 2), "0x50 is level 16 arrival 2")
	check(Run.decode(Run.SIDE_BYTE) == Vector2i(16, 3), "0x70 is level 16 arrival 3")
	check(Run.FORWARD_REGIONS == [1312, 1313] and Run.CIRCLE == 50 and Run.SIDE_REGION == 1318, "exit ids")
	check(Run.IGNORED_REGION == 1293 and not Run.KILL_REQUIRED and not Run.relocates_player(), "opcode 18 and kills stay off")
	check(Run.validate(Run.initial()).is_empty(), "initial state")
	var loaded: Dictionary = Run.initial()
	loaded.exit_region = 1312.0
	check(Run.validate(loaded).is_empty(), "a loaded float region validates")
	if failures == 0: print("PASS l17_cavern_run_test: four exits, killing optional")
	quit(1 if failures else 0)
