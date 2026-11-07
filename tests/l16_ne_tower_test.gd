extends SceneTree
const Tower = preload("res://scripts/lol2/l16_ne_tower.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Tower.DOORS == [92, 93, 94], "doors 92-94")
	check(Tower.LIP_REGION == 6079, "lip region")
	check(Tower.SECTIONS == 0, "no rise is hosted")
	check(Tower.TOWER_RECORD == 615, "centre tower is prop 615")
	check(Tower.ARRIVAL == Vector3(16082, 100, 3886), "arrival words stay data")
	check(Tower.validate(Tower.initial()).is_empty(), "initial state")
	var bad: Dictionary = Tower.initial()
	bad.erase("at_doors")
	check(not Tower.validate(bad).is_empty(), "a short state is refused")
	if failures == 0: print("PASS l16_ne_tower_test: doors, lip, no rise")
	quit(1 if failures else 0)
