extends SceneTree
const Hall = preload("res://scripts/lol2/l16_centre_tower.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Hall.DOOR_ID == -1, "Mantle Gate stays unbound")
	check(Hall.ACTOR == 45 and Hall.ACTOR_DEF == 1282, "actor 45 def 1282")
	check(not Hall.fight_hosted() and not Hall.relocates_player(), "no fight and no move")
	check(Hall.MANTLES == [331, 332, 333, 348], "mantle props")
	check(Hall.EXIT_REGIONS == [217, 218], "bar regions")
	check(Hall.NORTH_DOORS == [84, 85], "Jack doors stay listed, not the gate")
	check(Hall.validate(Hall.initial()).is_empty(), "initial state")
	var bad: Dictionary = Hall.initial()
	bad.erase("at_bars")
	check(not Hall.validate(bad).is_empty(), "a short state is refused")
	if failures == 0: print("PASS l16_centre_tower_test: door unbound, actor 45, no move")
	quit(1 if failures else 0)
