extends SceneTree
## BK00b. Opcode 207 adds signed byte 5 to the opcode-198 byte at slot byte 4.
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: " + message)
func _initialize() -> void:
	run.call_deferred()
func addend(slot: int, value: int) -> Dictionary:
	var bytes := PackedByteArray([207, 0, 0, 0, slot & 0xFF, value & 0xFF])
	return {"opcode": 207, "kind": 0, "target": 0, "file_offset": -1, "bytes": bytes, "raw_hex": bytes.hex_encode()}
func run() -> void:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L19_BC.json").is_empty(), "L19 loads")
	var up: Dictionary = host.execute_group(1, 5906)
	check(str(up.status) == "ran" and up.adapters == ["slot_index_binding"] and int(host.locals.get(0, -1)) == 1, "group 5906 adds 1 to slot 0 (%s adapters %s local %s)" % [up.status, up.adapters, host.locals.get(0, -1)])
	up = host.execute_group(1, 5906)
	check(str(up.status) == "ran" and int(host.locals.get(0, -1)) == 2, "a second group 5906 leaves slot 0 at 2 (%s)" % [host.locals.get(0, -1)])
	var down: Dictionary = host.execute_group(1, 5900)
	check(str(down.status) == "ran" and down.adapters.is_empty() and int(host.locals.get(0, -1)) == 1, "group 5900 subtracts 1 from slot 0 (%s %s)" % [down.status, host.locals.get(0, -1)])
	host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L19_BC.json").is_empty(), "L19 loads again")
	down = host.execute_group(1, 5900)
	check(str(down.status) == "ran" and int(host.locals.get(0, -1)) == 255, "an unread slot starts at 0, so group 5900 stores 255 (%s)" % [host.locals.get(0, -1)])
	host.groups[host.group_key(1, 990207)] = [addend(3, 1), addend(3, 1)]
	host.groups[host.group_key(1, 990208)] = [{"opcode": 207, "kind": 0, "target": 0, "file_offset": -1, "bytes": PackedByteArray([207, 0, 0, 0]), "raw_hex": "cf000000"}]
	var pair: Dictionary = host.execute_group(1, 990207)
	check(str(pair.status) == "ran" and int(host.locals.get(3, -1)) == 2, "two adds in one group accumulate (%s)" % [host.locals.get(3, -1)])
	var short: Dictionary = host.execute_group(1, 990208)
	check(str(short.status) == "unhosted" and str(short.reasons[0]).contains("shorter"), "a short command stays unhosted (%s)" % [short.reasons])
	if failures == 0:
		print("PASS opcode 207 adds signed byte 5 onto local slot byte 4")
	quit(0 if failures == 0 else 1)
