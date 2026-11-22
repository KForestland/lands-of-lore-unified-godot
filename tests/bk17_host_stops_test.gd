extends SceneTree
## BK17. Prop constructor +0x25, predicate type 4, and opcode 7 on a movable.
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: " + message)
func _initialize() -> void:
	run.call_deferred()
func row_for(results: Array, group: int) -> Dictionary:
	for raw in results:
		var row: Dictionary = raw
		if int(row.get("group", -1)) == group:
			return row
	return {}
func run() -> void:
	var l16 = Host.new()
	check(str(l16.load_area("res://scripts/lol2/native_scripts/L16_CA.json")).is_empty(), "L16 loads")
	check(int(l16.field("prop:626", "byte_0x25")) == 0, "prop 626 starts at +0x25 = 0")
	var fountain: Array = l16.fire_event("prop:626", 9, {"context": "prop:626", "word0": 0x20, "word2": 0, "dword_26": 0, "dword_1e": 255, "global_23331": 0})
	var fountain_row: Dictionary = row_for(fountain, 40510)
	check(str(fountain_row.get("status", "")) == "unhosted" and str(fountain_row.get("reasons", [])).contains("opcode 9 arm 0x10") and int(l16.field("prop:626", "byte_0x25")) == 0, "group 40510 passes predicate 206 and stops on opcode 9 arm 0x10 (%s)" % [fountain_row.get("reasons", [])])
	var l19 = Host.new()
	check(str(l19.load_area("res://scripts/lol2/native_scripts/L19_BC.json")).is_empty(), "L19 loads")
	var door: Array = l19.fire_event("movable:73", 4, {"arg_c": 0, "context": "movable:73"})
	var door_row: Dictionary = row_for(door, 5836)
	check(str(door_row.get("status", "")) == "ran" and (door_row.get("adapters", []) as Array).has("opcode7_movable_records") and int(l19.field("movable:73:records", "bit_0x03_0x02")) == 1, "group 5836 runs on opcode7_movable_records (%s)" % [door_row.get("status", "")])
	var l20 = Host.new()
	check(str(l20.load_area("res://scripts/lol2/native_scripts/L20_BB.json")).is_empty(), "L20 loads")
	check(int(l20.field("prop:242", "byte_0x25")) == 0 and int(l20.field("prop:87", "byte_0x25")) == 0, "props 242 and 87 start at +0x25 = 0")
	var mother: Array = l20.fire_event("prop:242", 6, {"caller_byte": 21, "context": "prop:242"})
	var mother_row: Dictionary = row_for(mother, 7704)
	check(str(mother_row.get("status", "")) == "unhosted" and str(mother_row.get("reasons", [])).contains("byte 4 35") and not l20.locals_e58.has(52), "group 7704 passes predicate 206 and still stops on opcode 2 arm 0x23 (%s)" % [mother_row.get("reasons", [])])
	var birth: Array = l20.fire_event("prop:87", 6, {"caller_byte": 20, "context": "prop:87"})
	var birth_row: Dictionary = row_for(birth, 770)
	check(str(birth_row.get("status", "")) == "rejected" and str(birth_row.get("reasons", [])).contains("predicate 219"), "group 770 stays rejected while +0x25 is 0 (%s)" % [birth_row.get("reasons", [])])
	if failures == 0:
		print("PASS BK17 host stops: prop +0x25 starts at 0, group 5836 runs, group 7704 does not write index 52")
	quit(0 if failures == 0 else 1)
