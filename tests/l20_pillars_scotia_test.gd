extends SceneTree
const Pillars = preload("res://scripts/lol2/l20_pillars_scotia.gd")
var failures: int = 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Pillars.FIRE == [57, 58, 59, 60, 61] and Pillars.ICE == 62 and Pillars.BLUE == -1, "fire row, ice sample, blue unbound")
	check(Pillars.SCOTIA == 48 and Pillars.OTHER_SCOTIA == 65 and Pillars.DRAR_PH == 47 and Pillars.PRISM == -1, "scotia actors, no prism")
	check(Pillars.TRINITY_LEVEL == 5 and not Pillars.relocates_player(), "trinity level, Luther stays")
	check(Pillars.DEST_BYTE == 0x53 and (Pillars.DEST_BYTE & 0x1F) == Pillars.DEST_LEVEL and (Pillars.DEST_BYTE >> 5) == Pillars.DEST_SELECTOR, "byte 0x53 splits to level 19 selector 2")
	check(Pillars.STAIR_REGIONS.size() == 10, "ten level-change regions")
	check(Pillars.validate(Pillars.initial()).is_empty(), "initial state")
	var bad: Dictionary = Pillars.initial()
	bad.shot = [62]
	check(not Pillars.validate(bad).is_empty(), "the ice pillar is refused")
	bad = Pillars.initial()
	bad.path_open = true
	check(not Pillars.validate(bad).is_empty(), "an open path before the five shots is refused")
	var shots: Dictionary = Pillars.initial()
	shots.shot = [57, 58, 59, 60, 61]
	shots.path_open = true
	check(Pillars.validate(shots).is_empty(), "five shots open the path before Trinity")
	shots.pillars_moved = true
	check(not Pillars.validate(shots).is_empty(), "the carrier stays until Trinity")
	var cast: Dictionary = Pillars.initial()
	cast.trinity = true
	cast.pillars_moved = true
	check(Pillars.validate(cast).is_empty(), "Trinity starts the carrier")
	cast.path_open = true
	check(not Pillars.validate(cast).is_empty(), "the path stays shut without the five shots")
	var open: Dictionary = Pillars.initial()
	open.shot = [57, 58, 59, 60, 61]
	open.trinity = true
	open.path_open = true
	open.pillars_moved = true
	check(Pillars.validate(open).is_empty(), "five fire shots and Trinity leave both open")
	if failures == 0: print("PASS l20_pillars_scotia_test: five shots open the path, Trinity starts the carrier")
	quit(1 if failures else 0)
