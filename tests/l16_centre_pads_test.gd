extends SceneTree
const Pads = preload("res://scripts/lol2/l16_centre_pads.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Pads.IN_CONTROL == 80 and Pads.OUT_CONTROL == 79, "controls 80 and 79")
	check(Pads.IN_GROUP == 42152 and Pads.OUT_GROUP == 42134, "groups 42152 and 42134")
	check(Pads.FLAGS == 0x0c04, "flags 0x0c04")
	check(Pads.IN_POSE == Vector3(5517, 32, 5640), "inbound floor 0 plus the foot offset")
	check(Pads.OUT_POSE == Vector3(-3923, -8, 7619), "outbound floor -40 plus the foot offset")
	check(not Pads.relocates_player(), "the module flags the pose as an adapter")
	if failures == 0: print("PASS l16_centre_pads_test: controls 79 and 80 store the centre pad words")
	quit(1 if failures else 0)
