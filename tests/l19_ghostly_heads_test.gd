extends SceneTree
const Heads = preload("res://scripts/lol2/l19_ghostly_heads.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Heads.HEADS == [67, 69, 68, 70] and Heads.FIFTH == 66, "four rectangle skulls")
	check(Heads.MIST_LEVEL == 1 and Heads.DEMON == -1 and Heads.PLATE == -1 and Heads.FOUNTAIN == -1 and Heads.STONE == -1, "level 1, no demon, plate, fountain, or stone")
	check(Heads.IMP == 31 and Heads.DISK == 57 and Heads.LIGHT == 65, "imp, disk, and light")
	check(not Heads.moves_player(), "opcode 18 does not move Luther")
	check(Heads.validate(Heads.initial()).is_empty(), "initial state")
	var bad: Dictionary = Heads.initial()
	bad.shot = [66]
	check(not Heads.validate(bad).is_empty(), "the fifth skull is refused")
	bad = Heads.initial()
	bad.dragged = true
	check(not Heads.validate(bad).is_empty(), "a drag is refused")
	if failures == 0: print("PASS l19_ghostly_heads_test: four skulls, imp 31, drag stays unbound")
	quit(1 if failures else 0)
