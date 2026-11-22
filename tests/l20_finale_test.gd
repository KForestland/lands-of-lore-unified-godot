extends SceneTree
const End = preload("res://scripts/lol2/l20_finale.gd")
var failures: int = 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(End.BELIAL == 75 and End.DRARACLE == 46 and End.CHASM == -1 and End.SCENE_NAME == "ending-adapter", "actor 75, actor 46, ending adapter")
	check(End.same_weapon("act2:L12_CM:blue_bow") and End.same_weapon("act2:L13_RC:dark_sword") and End.same_weapon("act2:L19_BC:horn"), "three weapons share the start")
	check(not End.same_weapon("act2:L16_CA:item24") and not End.same_weapon(""), "the Dark Bow and an empty hand stay out")
	check(End.plays_movie() and End.after_movie() and not End.moves_player() and not End.DAWN_ON_L20, "ending card, Luther stays, no Dawn row")
	check(End.validate(End.initial()).is_empty(), "initial state")
	var bad: Dictionary = End.initial()
	bad.started = true
	bad.weapon = "act2:L16_CA:item24"
	check(not End.validate(bad).is_empty(), "a different weapon is refused")
	bad = End.initial()
	bad.chasm = 0
	check(not End.validate(bad).is_empty(), "a chasm is refused")
	bad = End.initial()
	bad.appeared = true
	check(not End.validate(bad).is_empty(), "an appear flag is refused")
	var done: Dictionary = End.initial()
	done.started = true
	done.weapon = "act2:L19_BC:horn"
	done.chasm = 1
	done.slumped = true
	done.dawn_here = true
	done.appeared = true
	done.draracle_seen = true
	done.vanished = true
	check(End.validate(done).is_empty() and not End.finished(done), "the last card is not the finished flag")
	done.game_finished = true
	check(End.validate(done).is_empty() and End.finished(done) and End.BEAT >= 1.0, "the finished flag closes the sequence")
	if failures == 0: print("PASS l20_finale_test: three weapons, ending adapter, Luther stays")
	quit(1 if failures else 0)
