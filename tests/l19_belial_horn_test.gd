extends SceneTree
const Horn = preload("res://scripts/lol2/l19_belial_horn.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Horn.PROP == 222 and Horn.DEFINITION == 22 and Horn.IDENTITY == 213789840, "horn identity")
	check(Horn.ITEM == "act2:L19_BC:horn", "horn item id")
	check(Horn.ACTOR == 32 and Horn.ACTOR_REGION == 616 and Horn.PIPE_REGION == 687, "actor 32 stays off the pipe")
	check(not Horn.death_stored(), "no death flag")
	check(Horn.validate(Horn.initial()).is_empty(), "initial state")
	var bad: Dictionary = Horn.initial()
	bad.erase("taken")
	check(not Horn.validate(bad).is_empty(), "a short state is refused")
	if failures == 0: print("PASS l19_belial_horn_test: definition 22, no death flag, actor 32 stays apart")
	quit(1 if failures else 0)
