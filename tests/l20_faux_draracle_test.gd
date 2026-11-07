extends SceneTree
const Drar = preload("res://scripts/lol2/l20_faux_draracle.gd")
var failures: int = 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Drar.DRARACLE == 46 and Drar.BELIAL == 75 and Drar.GATEWAY == 52, "actor 46, actor 75, gateway 52")
	check(Drar.KEYS == [0, 1, 2] and Drar.SPEECH == "" and not Drar.moves_doors(), "three keys, no speech, doors stay still")
	check(Drar.validate(Drar.initial()).is_empty(), "initial state")
	var bad: Dictionary = Drar.initial()
	bad.struck = true
	bad.keys = [2]
	bad.room = false
	check(not Drar.validate(bad).is_empty(), "a skipped key is refused")
	bad = Drar.initial()
	bad.killed = true
	check(not Drar.validate(bad).is_empty(), "a kill is refused")
	if failures == 0: print("PASS l20_faux_draracle_test: actor 46, keys 0-2, kill stays false")
	quit(1 if failures else 0)
