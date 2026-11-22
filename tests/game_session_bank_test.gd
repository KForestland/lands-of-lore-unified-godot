extends SceneTree
const Session = preload("res://scripts/lol2/game_session.gd")
const Native = preload("res://scripts/lol2/native_script_host.gd")
class Progression extends Node:
	var native = Native.new()
	var area_id := "L9_DR"
	var struck_durability := {"movable:115": 12}
	var hinges:Dictionary={}
	func floor_checkpoint()->Dictionary:return {"version":1,"clock":0.0,"motions":{}}
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var session := Session.new(); root.add_child(session)
	var p := Progression.new(); root.add_child(p)
	assert(p.native.load_area("res://scripts/lol2/native_scripts/L9_DR.json").is_empty())
	p.native.set_local(3, 17); p.native.set_local_e58(52, -4); p.native.record_state[27] = {"byte5": 1}
	session.store_current(p)
	var packet := session.bank_for("L9_DR")
	assert(packet.locals["3"] == 17 and packet.record_state["27"].byte5 == 1)
	assert(packet.world=={"version":1,"floors":{"version":1,"clock":0.0,"motions":{}},"movers":{}},"Physical continuation is part of the same-build snapshot")
	assert(packet.locals_e58.is_empty() and session.native_globals.locals_e58["52"]==-4,"One game-wide cell table, not a per-area copy")
	packet.locals["3"] = 55
	assert(session.bank_for("L9_DR").locals["3"] == 17)
	var before := session.snapshot_bank()
	assert(not session.replace_bank({"bad":{}}).is_empty() and session.snapshot_bank() == before)
	assert(session.take_seed_override() == null)
	session.set_seed_override(false)
	assert(session.take_seed_override() == false and session.take_seed_override() == null)
	# Replacement uses only the holder's validated canonical shape; no raw tree bank.
	assert(session.replace_bank({"L8_SJ":{"state":{},"locals":{"13":7},"locals_e58":{},"record_state":{"5":{"byte5":1}},"struck_durability":{}}}).is_empty())
	assert(session.bank_for("L8_SJ").locals["13"] == 7)
	p.free(); session.free()
	print("PASS session owns canonical native bank, deep copies, atomic refusal, transient seed override and canonical replacement")
	quit()
