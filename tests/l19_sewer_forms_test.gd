extends SceneTree
const Forms = preload("res://scripts/lol2/l19_sewer_forms.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Forms.BARS == -1 and Forms.GUTTER == -1, "no bars and no gutter")
	check(not Forms.bars_breakable(0) and not Forms.gutter_enterable(2), "form checks do not invent a mesh")
	check(Forms.SWITCHES == [74, 75, 76] and Forms.RECORD_REGIONS == [36, 34, 32] and Forms.NAV_REGION == 30, "switch ids")
	check(Forms.DOOR == 77 and not Forms.moves_door(), "sewer door stays still")
	check(Forms.validate(Forms.initial()).is_empty(), "initial state")
	var bad: Dictionary = Forms.initial()
	bad.switches = [74, 74]
	check(not Forms.validate(bad).is_empty(), "a duplicate switch is refused")
	if failures == 0: print("PASS l19_sewer_forms_test: bars and gutter stay unbound")
	quit(1 if failures else 0)
