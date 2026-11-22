extends SceneTree
const Hall = preload("res://scripts/lol2/l16_centre_tower.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Hall.DOOR_ID == -1, "Mantle Gate has no door id")
	check(Hall.ACTOR == 45 and Hall.ACTOR_DEF == 1282, "actor 45 def 1282")
	check(Hall.fight_hosted() and not Hall.relocates_player(), "the foe is hosted and Luther stays")
	check(Hall.MANTLES == [331, 332, 333, 348], "mantle props")
	check(Hall.pose_for(331) == Vector3(5334, 40, 9622), "prop 331 stored words")
	check(Hall.pose_for(332) == Vector3(5713, 40, 9617), "prop 332 stored words")
	check(Hall.pose_for(333) == Vector3(5809, 40, 9893), "prop 333 stored words")
	check(Hall.pose_for(348) == Vector3(5201, 40, 9893), "prop 348 stored words")
	check(Hall.EXIT_REGIONS == [216, 217, 218], "bar regions")
	check(Hall.BARS == Vector3(5511, 32, 9888), "region 218 stand")
	check(Hall.NORTH_DOORS == [84, 85], "Jack doors stay listed, not the gate")
	check(Hall.validate(Hall.initial()).is_empty(), "initial state")
	var bad: Dictionary = Hall.initial()
	bad.erase("at_bars")
	check(not Hall.validate(bad).is_empty(), "a short state is refused")
	var down: Dictionary = Hall.initial()
	down.seen_actor = true
	down.foe_down = true
	check(Hall.validate(down).is_empty(), "a kill validates")
	var bars: Dictionary = Hall.initial()
	bars.conveyed = true
	check(Hall.validate(bars).is_empty(), "conveyed validates")
	if failures == 0: print("PASS l16_centre_tower_test: no door id, mantle words stored, Luther stays")
	quit(1 if failures else 0)
