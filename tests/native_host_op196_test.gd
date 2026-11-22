extends SceneTree
## BK00a. Opcode 196, byte 6 = 0, stages the signed floor word and the rate. Byte 6 = 1 runs only by adapter
## opcode196_word_select (L19 cab slot, lead 2026-11-14): it stages ceiling_target and no floor; other byte 6 values stay unhosted.
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: " + message)
func _initialize() -> void:
	run.call_deferred()
func command(region: int, target: int, flags: int, rate: int) -> Dictionary:
	var bytes := PackedByteArray([
		196, 0x90, region & 0xFF, (region >> 8) & 0xFF,
		target & 0xFF, (target >> 8) & 0xFF, flags & 0xFF, rate & 0xFF, 0, 0, 0, 0])
	return {"opcode": 196, "kind": 0x90, "target": region, "file_offset": -1, "bytes": bytes, "raw_hex": bytes.hex_encode()}
func run() -> void:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L19_BC.json").is_empty(), "L19 loads")
	host.groups[host.group_key(1, 990196)] = [command(40, -20, 0, 2)]
	host.groups[host.group_key(1, 990197)] = [command(1932, 40, 1, 2)]
	host.groups[host.group_key(1, 990198)] = [command(42, 40, 2, 2)]
	var open: Dictionary = host.execute_group(1, 990196)
	check(str(open.status) == "ran" and open.adapters.is_empty(), "byte 6 = 0 runs with no adapter (%s)" % [open.reasons])
	check(int(host.field("0x22d0c:40", Host.FIELD_FLOOR_TARGET, 0)) == -20, "region 40 target is -20")
	check(int(host.field("0x22d0c:40", Host.FIELD_FLOOR_RATE, -1)) == 2, "region 40 rate is 2")
	var word: Dictionary = host.execute_group(1, 990197)
	check(str(word.status) == "ran" and "opcode196_word_select" in word.adapters, "byte 6 = 1 runs by adapter opcode196_word_select (%s %s)" % [word.status, word.reasons])
	check(int(host.field("0x22d0c:1932", "ceiling_target", 0)) == 40 and int(host.field("0x22d0c:1932", Host.FIELD_FLOOR_TARGET, 777)) == 777, "byte 6 = 1 stages ceiling_target 40 and no floor target")
	var shut: Dictionary = host.execute_group(1, 990198)
	check(str(shut.status) == "unhosted" and str(shut.reasons[0]).contains("byte 6"), "byte 6 = 2 stays unhosted (%s)" % [shut.reasons])
	host.groups[host.group_key(1, 990199)] = [command(41, 40, 1, 2)]
	var other: Dictionary = host.execute_group(1, 990199)
	check(str(other.status) == "unhosted" and str(other.reasons[0]).contains("byte 6"), "byte 6 = 1 on another region stays unhosted (%s)" % [other.reasons])
	host.set_adapter_enabled("opcode196_word_select", false)
	var off: Dictionary = host.execute_group(1, 990197)
	check(str(off.status) == "unhosted" and str(off.reasons[0]).contains("byte 6"), "byte 6 = 1 with the adapter off stays unhosted (%s)" % [off.reasons])
	var bars: Dictionary = host.execute_group(1, 7898)
	check(str(bars.status) == "ran" and bars.adapters.is_empty(), "group 7898 runs (%s)" % [bars.reasons])
	var band := [40, 61, 62, 63, 64, 65, 66, 67, 68, 69]
	var raised := true
	for region in band:
		if int(host.field("0x22d0c:%d" % region, Host.FIELD_FLOOR_TARGET, 0)) != -20:
			raised = false
	check(raised, "group 7898 targets regions 40 and 61-69 at -20")
	if failures == 0:
		print("PASS opcode 196 stages floor targets for byte 6 = 0, byte 6 = 1 by adapter (ceiling_target), other byte 6 values unhosted")
	quit(0 if failures == 0 else 1)
