extends SceneTree
const Carry = preload("res://scripts/lol2/l17_beast_carry.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Carry.GROUP == 1566 and Carry.TRIGGER_REGION == 1293 and Carry.TARGET == 0, "group 1566 on region 1293 target 0")
	check(Carry.FLAGS == 0x0005 and Carry.direct_relocation(), "flags 0x0005 are the direct form and do not assign height")
	check(Carry.WORD_X == -6084 and Carry.WORD_Y == -6404 and Carry.HEADING_UNITS == 18386, "stored words and heading")
	check(Carry.READER_AT.is_equal_approx(Vector3(-6084, 32, 6404)) and Carry.READER_REGION == 1259, "reader landing is region 1259")
	check(Carry.LAND_REGION == 1292 and Carry.LAND_REGION >= Carry.EXIT_LO and Carry.LAND_REGION <= Carry.EXIT_HI, "exit pose is inside 1279-1314")
	check(Carry.READER_REGION < Carry.EXIT_LO or Carry.READER_REGION > Carry.EXIT_HI, "the stored words are outside the exit block")
	check(Carry.POCKET_REGION == 1271 and Carry.relocates_player(), "the pocket cut relocates")
	check(Carry.validate(Carry.initial()).is_empty(), "initial state")
	var bad: Dictionary = Carry.initial()
	bad.erase("carried")
	check(not Carry.validate(bad).is_empty(), "a short state is refused")
	if failures == 0: print("PASS l17_beast_carry_test: opcode 18 words land in region 1259 and the pocket cut poses region 1292")
	quit(1 if failures else 0)
