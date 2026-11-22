extends SceneTree
## BK00c. Opcode 199 stores unsigned byte 5 at [0x26E58] + byte 4 when the value is 0, 1, or 2.
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: " + message)
func _initialize() -> void:
	run.call_deferred()
func store(index: int, value: int) -> Dictionary:
	var bytes := PackedByteArray([199, 0, 0, 0, index & 0xFF, value & 0xFF])
	return {"opcode": 199, "kind": 0, "target": 0, "file_offset": -1, "bytes": bytes, "raw_hex": bytes.hex_encode()}
func run() -> void:
	var host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L20_BB.json").is_empty(), "L20 loads")
	var gate_commands: Array = host.groups[host.group_key(1, 7704)]
	check(str(gate_commands[3]["raw_hex"]) == "c70000003401", "group 7704 carries the gate store")
	var blocked: Dictionary = host.execute_group(1, 7704)
	check(str(blocked.status) == "unhosted" and str(blocked.reasons).contains("byte 4 35") and not host.locals_e58.has(52), "group 7704 stops on opcode 2 arm 0x23 and does not write index 52 (%s)" % [blocked.reasons])
	var high: Dictionary = host.execute_group(1, 316)
	check(str(high.status) == "unhosted" and str(high.reasons).contains("byte 5 is 20") and not host.locals_e58.has(1), "group 316 byte 5 = 20 stays unresolved (%s)" % [high.reasons])
	host.groups[host.group_key(1, 990199)] = [store(52, 1)]
	var wrote: Dictionary = host.execute_group(1, 990199)
	check(str(wrote.status) == "ran" and int(host.locals_e58.get(52, -1)) == 1, "c70000003401 stores 1 at index 52 (%s)" % [host.locals_e58.get(52, -1)])
	host.groups[host.group_key(1, 990200)] = [store(52, 0), store(52, 2)]
	var pair: Dictionary = host.execute_group(1, 990200)
	check(str(pair.status) == "ran" and int(host.locals_e58.get(52, -1)) == 2, "a later store in the same group sees the staged cell (%s)" % [host.locals_e58.get(52, -1)])
	host.set_local_e58(7, 0)
	host.groups[host.group_key(1, 990201)] = [store(7, 1), {"opcode": 199, "kind": 0, "target": 0, "file_offset": -1, "bytes": PackedByteArray([199, 0, 0, 0]), "raw_hex": "c7000000"}]
	var rolled: Dictionary = host.execute_group(1, 990201)
	check(str(rolled.status) == "unhosted" and str(rolled.reasons).contains("shorter") and int(host.locals_e58.get(7, -1)) == 0, "a short command rolls the staged store back (%s %s)" % [rolled.reasons, host.locals_e58.get(7, -1)])
	host = Host.new()
	check(host.load_area("res://scripts/lol2/native_scripts/L7_DH.json").is_empty(), "L7 loads")
	host.set_global(0x223D6, 0)
	var exit_group: Dictionary = host.execute_group(0, 856)
	check(str(exit_group.status) == "ran" and int(host.locals_e58.get(3, -1)) == 1 and int(host.globals.get(0x223C8, -1)) == 4 and int(host.globals.get(0x223CC, -1)) == 6, "L7 group 856 stores slot 3 = 1 and arms level 4 selector 6 (%s e58 %s)" % [exit_group.status, host.locals_e58.get(3, -1)])
	if failures == 0:
		print("PASS opcode 199 stores byte 5 at 0x26E58 plus byte 4 when the value is 0, 1, or 2")
	quit(0 if failures == 0 else 1)
