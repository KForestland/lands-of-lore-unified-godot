extends SceneTree
const Room = preload("res://scripts/lol2/l16_dragon_room.gd")
var failures := 0
func check(ok: bool, m: String) -> void:
	if not ok: failures += 1; print("FAIL ", m)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Room.DRAGON == 241 and Room.STATUE == 211 and Room.TELEPAD == 74, "dragon, statue, pad")
	check(Room.DOOR_ID == -1 and Room.PAD_BYTE == 0x31, "no door, byte 0x31")
	check(Room.DEST_LEVEL == 17 and Room.DEST_SELECTOR == 1 and Room.DEST_AREA == "L17_HC", "Hive Caverns arrival 1")
	check(Room.DEST_POSE == Vector3(1434, 32, -7075), "arrival pose")
	check(not Room.relocates_player(), "module does not move Luther")
	check(Room.validate(Room.initial()).is_empty(), "initial state")
	var s: Dictionary = Room.initial()
	check(Room.apply_chop(s, Room.STATUE) == s, "the statue does not chop")
	var chopped: Dictionary = Room.apply_chop(s, Room.DRAGON)
	check(bool(chopped.chopped) and not bool(chopped.pad_seen), "prop 241 chops")
	check(not bool(Room.apply_pad(s).pad_seen), "the pad waits for the chop")
	var seen: Dictionary = Room.apply_pad(chopped)
	check(bool(seen.pad_seen), "the pad records after the chop")
	if failures == 0: print("PASS l16_dragon_room_test: chop 241, not 211, level 17 arrival 1")
	quit(1 if failures else 0)
