extends SceneTree
const Pillars = preload("res://scripts/lol2/l20_pillars_scotia.gd")
var failures: int = 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Pillars.FIRE == [57, 58, 59, 60, 61] and Pillars.ICE == 62 and Pillars.BLUE == -1, "fire row, ice sample, blue unbound")
	check(Pillars.SCOTIA == 48 and Pillars.OTHER_SCOTIA == 65 and Pillars.DRAR_PH == 47 and Pillars.PRISM == -1, "scotia actors, no prism")
	check(Pillars.TRINITY_LEVEL == 5 and not Pillars.opens_path() and not Pillars.moves_pillars() and not Pillars.relocates_player(), "trinity level, path stays closed")
	check(Pillars.DEST_BYTE == 0x53 and (Pillars.DEST_BYTE & 0x1F) == Pillars.DEST_LEVEL and (Pillars.DEST_BYTE >> 5) == Pillars.DEST_SELECTOR, "byte 0x53 splits to level 19 selector 2")
	check(Pillars.STAIR_REGIONS.size() == 10, "ten level-change regions")
	check(Pillars.validate(Pillars.initial()).is_empty(), "initial state")
	var bad: Dictionary = Pillars.initial()
	bad.shot = [62]
	check(not Pillars.validate(bad).is_empty(), "the ice pillar is refused")
	bad = Pillars.initial()
	bad.path_open = true
	check(not Pillars.validate(bad).is_empty(), "an open path is refused")
	if failures == 0: print("PASS l20_pillars_scotia_test: fire row, actor 48, stairs unbound")
	quit(1 if failures else 0)
