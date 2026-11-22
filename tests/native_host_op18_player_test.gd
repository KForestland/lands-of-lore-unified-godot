extends SceneTree
## BK00d. Opcode 18 kind 1 target 0 with flag 0x0004 is the player pose.
## Real groups: L16 stream 1 groups 42152 and 42134, L17 stream 0 group 1566,
## L20 stream 1 group 770 commits the birth pose once opcode 2 arm 0 returns.
const Host := preload("res://scripts/lol2/native_script_host.gd")
const Prog := preload("res://scripts/lol2/act2_progression.gd")
var failures := 0

class Holder extends Node3D:
	var player: Node3D

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", message)

func _initialize() -> void:
	run.call_deferred()

func pose_of(result: Dictionary) -> Dictionary:
	for effect in result.get("effects", []):
		if str(effect.get("type", "")) == "player_pose":
			return effect
	return {}

func reason(result: Dictionary) -> String:
	var reasons: Array = result.get("reasons", [])
	return str(reasons[0]) if not reasons.is_empty() else ""

func run() -> void:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L16_CA.json").is_empty(), "L16 loads")
	var inbound: Dictionary = host.execute_group(1, 42152)
	var in_pose: Dictionary = pose_of(inbound)
	var in_slot: int = host.field("0xb7d5e", "command_file_offset")
	check(str(inbound.status) == "ran" and inbound.adapters.has("opcode18_pending_slot"), "group 42152 runs on the slot adapter (%s)" % reason(inbound))
	check(in_slot == 0 and int(in_pose.get("x", 1)) == 5517 and int(in_pose.get("y", 0)) == -5640, "group 42152 stores words (5517, -5640) and the reader clears the slot (%s slot %d)" % [in_pose, in_slot])
	check(bool(in_pose.get("apply_height", true)) == false and int(in_pose.get("flags", 0)) == 0x0c04 and int(in_pose.get("heading", -1)) == 32768, "group 42152 keeps height and heading 32768")
	var body := CharacterBody3D.new()
	body.position = Vector3(0, -8, 0)
	var map := Holder.new()
	map.player = body
	root.add_child(map)
	map.add_child(body)
	var prog = Prog.new()
	prog.host = map
	prog.native = host
	prog.area_id = "L16_CA"
	# The VM normally clears this itself; retain the consumer cleanup for every area.
	host.set_field("0xb7d5e", "command_file_offset", 424242)
	prog.consume_player_poses([inbound])
	var landed: bool = body.position.distance_to(Vector3(5517, -8, 5640)) < 0.01
	landed = landed and absf(angle_difference(body.rotation.y, Prog.player_pose_yaw(32768))) < 0.0001
	landed = landed and body.velocity == Vector3.ZERO
	check(landed, "Luther keeps height -8 at the inbound words, facing heading 32768 (%s)" % body.position)
	check(host.field("0xb7d5e", "command_file_offset") == 0, "the consumer clears the slot after the pose")
	var outbound: Dictionary = host.execute_group(1, 42134)
	var out_pose: Dictionary = pose_of(outbound)
	check(str(outbound.status) == "ran" and int(out_pose.get("x", 0)) == -3923 and int(out_pose.get("y", 0)) == -7619 and int(out_pose.get("heading", -1)) == 0, "a cleared slot takes group 42134 words (-3923, -7619)")
	var l17 = Host.new()
	check(l17.load_area("res://scripts/lol2/native_scripts/L17_HC.json").is_empty(), "L17 loads")
	var carry: Dictionary = l17.execute_group(0, 1566)
	var carry_pose: Dictionary = pose_of(carry)
	check(str(carry.status) == "ran" and carry.adapters.has("opcode12_room") and int(carry_pose.get("x", 0)) == -6084 and int(carry_pose.get("y", 0)) == -6404, "group 1566 poses (-6084, -6404) (%s)" % reason(carry))
	check(bool(carry_pose.get("apply_height", true)) == false and int(carry_pose.get("heading", 0)) == 18386 and int(carry_pose.get("flags", 0)) == 0x0005, "region 1293 keeps height and heading 18386")
	body.position = Vector3(0, 32, 0)
	body.rotation.y = 0.4
	Prog.apply_player_pose_effects([carry], body)
	var reader: bool = body.position.distance_to(Vector3(-6084, 32, 6404)) < 0.01
	reader = reader and absf(angle_difference(body.rotation.y, Prog.player_pose_yaw(18386))) < 0.0001
	check(reader, "region 1293 stands on the kept height at the opcode 18 words (%s)" % body.position)
	var l20 = Host.new()
	check(l20.load_area("res://scripts/lol2/native_scripts/L20_BB.json").is_empty(), "L20 loads")
	var birth: Dictionary = l20.execute_group(1, 770)
	var birth_pose: Dictionary = pose_of(birth)
	check(str(birth.status) == "ran" and birth.adapters.has("opcode2_arm0_clear"), "group 770 runs past arm 0 (%s)" % reason(birth))
	var birth_words: bool = int(birth_pose.get("x", 0)) == -1382 and int(birth_pose.get("y", 0)) == 3213 and bool(birth_pose.get("apply_height", true)) == false and int(birth_pose.get("heading", -1)) == 0x4000 and int(birth_pose.get("flags", 0)) == 0x0085
	check(birth_words, "group 770 poses (-1382, 3213), keeps height, heading 0x4000 (%s)" % birth_pose)
	var saw_movie: bool = false
	for effect in birth.get("effects", []):
		if str(effect.get("type", "")) == "movie" and int(effect.get("index", -1)) == 65 and str(effect.get("name", "")) == "bb_brth":
			saw_movie = true
	check(saw_movie, "group 770 requests movie 65 bb_brth")
	check(l20.field("prop:87", "byte_0x25") == 14, "opcode 16 stores 14 on prop 87")
	body.position = Vector3(10, 12, 30)
	body.rotation.y = 0.2
	Prog.apply_player_pose_effects([birth], body)
	var born: bool = body.position.distance_to(Vector3(-1382, 12, -3213)) < 0.01
	born = born and absf(angle_difference(body.rotation.y, Prog.player_pose_yaw(0x4000))) < 0.0001
	check(born, "the consumer keeps height 12 at the birth words (%s)" % body.position)
	var height_hex := "120100001000200028000401004000000000"
	l17.groups[l17.group_key(1, 970020)] = [_cmd(height_hex, 970020)]
	l17.set_field("0xb7d5e", "command_file_offset", 0)
	var raised: Dictionary = l17.execute_group(1, 970020)
	var raised_pose: Dictionary = pose_of(raised)
	body.position = Vector3(0, 7, 0)
	Prog.apply_player_pose_effects([raised], body)
	check(str(raised.status) == "ran" and bool(raised_pose.get("apply_height", false)) and body.position.distance_to(Vector3(16, 40, -32)) < 0.01, "flag 0x0100 writes the height word (%s)" % body.position)
	check(absf(angle_difference(body.rotation.y, Prog.player_pose_yaw(0x4000))) < 0.0001, "heading 0x4000")
	l17.set_field("0xb7d5e", "command_file_offset", 0)
	l17.groups[l17.group_key(1, 970021)] = [_cmd("120105000000000000000400000000000000", 970021)]
	var other: Dictionary = l17.execute_group(1, 970021)
	check(str(other.status) == "ran" and pose_of(other).is_empty() and l17.field("0xb7d5e", "command_file_offset") == 0, "target word 5 does not pose, and the reader clears the slot")
	var followed: Dictionary = l17.execute_group(1, 970020)
	var followed_pose: Dictionary = pose_of(followed)
	body.position = Vector3(0, 7, 0)
	Prog.apply_player_pose_effects([followed], body)
	check(str(followed.status) == "ran" and bool(followed_pose.get("apply_height", false)) and body.position.distance_to(Vector3(16, 40, -32)) < 0.01, "a player opcode 18 after a non-player opcode 18 still poses (%s)" % body.position)
	l17.set_field("0xb7d5e", "command_file_offset", 4242)
	var held_off: Dictionary = l17.execute_group(1, 970020)
	check(str(held_off.status) == "ran" and pose_of(held_off).is_empty() and l17.field("0xb7d5e", "command_file_offset") == 0, "a slot that is already full does not pose, and the reader still clears it")
	l17.groups[l17.group_key(1, 970025)] = [_cmd("120105000000000000000400000000000000", 970025), _cmd("120100001000200028000401004000000000", 970026)]
	var both: Dictionary = l17.execute_group(1, 970025)
	check(str(both.status) == "ran" and int(pose_of(both).get("x", 0)) == 16 and l17.field("0xb7d5e", "command_file_offset") == 0, "one group clears the non-player opcode 18 before the player opcode 18")
	l17.set_field("0xb7d5e", "command_file_offset", 0)
	var slide: Dictionary = _one(l17, "120100000000000000000100000000000000", 970022)
	check(str(slide.status) == "ran" and pose_of(slide).is_empty(), "flag 0x0004 clear does not pose")
	check(reason(_one(l17, "120100000000000000002000000000000000", 970023)).contains("0x660F8"), "bit 5 of the word +0xA still refuses")
	l17.set_adapters_enabled(false)
	check(reason(_one(l17, "120100001000200028000401004000000000", 970024)).contains("opcode18_pending_slot off"), "the slot adapter still gates the pose")
	prog.free()
	map.free()
	if failures == 0:
		print("PASS opcode 18 player pose: pads and region 1293 keep height, flag 0x0100 writes it, group 770 commits the birth pose")
	quit(0 if failures == 0 else 1)

func _cmd(hex: String, group: int) -> Dictionary:
	var bytes := hex.hex_decode()
	return {"opcode": int(bytes[0]), "kind": int(bytes[1]), "target": bytes.decode_u16(2), "file_offset": 800000 + group, "bytes": bytes, "raw_hex": hex}

func _one(host, hex: String, group: int) -> Dictionary:
	host.groups[host.group_key(1, group)] = [_cmd(hex, group)]
	return host.execute_group(1, group)
