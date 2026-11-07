extends SceneTree
const Traps = preload("res://scripts/lol2/l16_nw_traps.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Traps.BRICK == 88 and Traps.FIRE == 89 and Traps.ICE == 90, "props 88, 89, 90")
	check(Traps.DOORS == [86, 87, 88], "firewall doors stay listed")
	check(Traps.accepts_fire(Traps.BLUE), "the blue bow meets the fireball")
	check(not Traps.accepts_fire("act2:L13_RC:dark_sword"), "the dark sword is a different weapon")
	check(not Traps.accepts_fire(""), "an empty hand leaves the fireball")
	check(Traps.validate(Traps.initial()).is_empty(), "initial state")
	var bad: Dictionary = Traps.initial()
	bad.ice = 1
	check(not Traps.validate(bad).is_empty(), "a numeric ice flag is refused")
	if failures == 0: print("PASS l16_nw_traps_test: three props, blue bow only")
	quit(1 if failures else 0)
