extends SceneTree
const Arm = preload("res://scripts/lol2/l20_armory.gd")
var failures: int = 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Arm.LEFTMOST == 62 and Arm.OTHER == 67 and Arm.BRICK == -1 and Arm.BALL == -1 and Arm.FIREBALL == -1, "westernmost block, objects unbound")
	check(Arm.SOURCES == [195, 196, 197] and Arm.PYRAPOD == -1 and Arm.IMP_LEVEL == 3, "sources and the book levels stay unbound")
	check(not Arm.stops_pillars(), "pillars do not stop")
	check(Arm.validate(Arm.initial()).is_empty(), "initial state")
	var bad: Dictionary = Arm.initial()
	bad.ball = true
	check(not Arm.validate(bad).is_empty(), "a white-ball flag is refused")
	bad = Arm.initial()
	bad.fire = true
	check(not Arm.validate(bad).is_empty(), "a fireball flag is refused")
	if failures == 0: print("PASS l20_armory_test: block 62, brick and balls unbound")
	quit(1 if failures else 0)
