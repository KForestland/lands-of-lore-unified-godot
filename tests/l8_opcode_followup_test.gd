extends SceneTree
const Ladder = preload("res://scripts/lol2/l8_cache_ladder.gd")
const Bridge = preload("res://scripts/lol2/l8_tree_bridge.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	check(not Ladder.OP20_PLAYED and Ladder.SOUND_ID == 780 and Ladder.SOUND_NAME == "creaky2.aud", "ladder sound 780 stays unplayed")
	check(not Bridge.OP20_PLAYED and Bridge.SOUND_ID == 780 and Bridge.SOUND_NAME == "creaky2.aud", "tree sound 780 stays unplayed")
	check(not Bridge.OP9_ENTERED and Bridge.OP9_ARM2 == "player_release" and Bridge.OP9_ARM3 == "link", "arm 2 releases the player and arm 3 links")
	check(Ladder.CONTROL == 69 and Bridge.TREE == 114 and Bridge.BRIDGE == 116, "the same controls stay")
	if failures == 0: print("PASS l8 opcode follow-up: creaky2 stays unplayed")
	quit(1 if failures else 0)
