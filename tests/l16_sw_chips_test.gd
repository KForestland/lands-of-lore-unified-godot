extends SceneTree
const Foyer = preload("res://scripts/lol2/l16_sw_chips.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Foyer.CHIP_IDS.size() == 5, "five known chip ids")
	check("act2:L16_CA:item24" not in Foyer.CHIP_IDS, "the Dark Bow is not a chip")
	check(Foyer.PYRAMID == 604 and Foyer.DOORS == [89, 90, 91], "pyramid and doors stay listed")
	check(Foyer.validate(Foyer.initial()).is_empty(), "initial state")
	check(Foyer.apply_place(Foyer.initial(), 0, "act2:L16_CA:item99") == Foyer.initial(), "an unknown id is refused")
	var s: Dictionary = Foyer.initial()
	for index in 4:
		s = Foyer.apply_place(s, index, str(Foyer.CHIP_IDS[index]))
	check(s.placed.size() == 4 and int(s.placed[0]) == 0 and int(s.placed[1]) == 1 and int(s.placed[2]) == 2 and int(s.placed[3]) == 3, "four pedestals take four known chips")
	check(Foyer.apply_place(s, 0, str(Foyer.CHIP_IDS[4])) == s, "a filled pedestal stays")
	check(Foyer.validate(s).is_empty(), "four chips validate")
	var floats: Dictionary = s.duplicate(true)
	floats.placed = [0.0, 1.0, 2.0, 3.0]
	check(Foyer.validate(floats).is_empty(), "loaded floats validate")
	if failures == 0: print("PASS l16_sw_chips_test: five chip ids, four pedestals")
	quit(1 if failures else 0)
