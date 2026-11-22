extends SceneTree
const Forms = preload("res://scripts/lol2/l19_sewer_forms.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Forms.BARS == -1 and Forms.GUTTER == -1, "no bars and no gutter")
	check(Forms.bars_breakable(0) and not Forms.bars_breakable(2) and Forms.gutter_enterable(2) and not Forms.gutter_enterable(0), "Human breaks bars, Lizard enters the gutter")
	check(Forms.SWITCHES == [74, 75, 76] and Forms.RECORD_REGIONS == [36, 34, 32] and Forms.NAV_REGION == 30, "switch ids")
	check(Forms.DOOR == 77 and not Forms.moves_door() and Forms.BARS == -1 and Forms.GUTTER == -1, "the bars group does not travel the door")
	check(Forms.validate(Forms.initial()).is_empty(), "initial state")
	var bad: Dictionary = Forms.initial()
	bad.switches = [74, 74]
	check(not Forms.validate(bad).is_empty(), "a duplicate switch is refused")
	var counted: Dictionary = Forms.initial()
	counted["counter"] = 2
	check(Forms.validate(counted).is_empty(), "a saved counter is kept")
	counted["counter"] = 256
	check(not Forms.validate(counted).is_empty(), "a counter past 255 is refused")
	check(Forms.BLUE_BOW == "act2:L12_CM:blue_bow" and Forms.DARK_BOW == "act2:L16_CA:item24", "the two bow ids")
	if failures == 0: print("PASS l19_sewer_forms_test: Human bars, Lizard gutter, ids stay unbound")
	quit(1 if failures else 0)
