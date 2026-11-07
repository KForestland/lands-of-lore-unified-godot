extends SceneTree
## Headless: the L3_DH torch switch and the 35 Museum wall torches (museum_torches.gd), and the Long arm
## Classic/Enhanced split (owner 2026-10-28). Native chain: movable52 kind4 mode0 (E, empty hand) sets prop61 state1
## (props start at state0: object init AE990 zeroes +0x25); a Spark on prop61 is admitted only at state1 and only
## once, then group70 lights every torch. A single torch can also be lit on its own.
const Torches = preload("res://scripts/lol2/museum_torches.gd")
const Arm = preload("res://scripts/lol2/museum_long_arm.gd")
const ArmState = preload("res://scripts/lol2/museum_long_arm_state.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

class Curse extends RefCounted:
	func requests_enabled() -> bool: return true

class Host extends Node3D:
	var feedback: Array = []
	var curse = Curse.new()
	func save_feedback(text: String) -> void: feedback.append(text)

func run() -> void:
	check(Torches.assets_ready(), "torch media staged (tools/prepare_museum_torches.py)")
	var src := Torches.load_source()
	check(src.get("torches", {}).size() == 35 and src.get("order", []).size() == 35, "35 torches in group70 order")
	check(src.get("order", []).all(func(id): return src.torches.has(str(int(id)))), "every group70 target is a torch row")
	# Save shape.
	check(Torches.validate(null).is_empty(), "older saves without the field load")
	check(Torches.validate(Torches.initial()).is_empty(), "initial state valid")
	check(not Torches.validate({"version": 1, "pilot_state": 0, "pilot_spent": true, "lit": []}).is_empty(), "spent pilot at state0 refused")
	check(not Torches.validate({"version": 1, "pilot_state": 1, "pilot_spent": true, "lit": [63]}).is_empty(), "spent pilot with unlit torches refused")
	check(not Torches.validate({"version": 1, "pilot_state": 0, "pilot_spent": false, "lit": [63, 63]}).is_empty(), "duplicate torch refused")
	check(not Torches.validate({"version": 1, "pilot_state": 0, "pilot_spent": false, "lit": [9999]}).is_empty(), "unknown torch refused")
	check(not Torches.validate({"version": 1, "pilot_state": 2, "pilot_spent": false, "lit": []}).is_empty(), "pilot state outside 0/1 refused")
	# Live logic on a bare host (no camera: reach is covered by the rendered Museum tests).
	var host := Host.new()
	root.add_child(host)
	var t: Node3D = Torches.new()
	host.add_child(t)
	var error: String = t.setup(host, null)
	check(error.is_empty(), "setup: " + error)
	if error.is_empty():
		check(int(t.state.pilot_state) == 0 and not t.state.pilot_spent and t.state.lit.is_empty(), "start: plate up, pilot unspent, all torches dark")
		t.receive_hit("61", 1, 1, Torches.SPARK_DAMAGE)
		check(not t.state.pilot_spent and t.state.lit.is_empty(), "Spark on the pilot before the plate (state0): nothing")
		t.receive_hit("61", 1, 1, 0)
		check(not t.state.pilot_spent, "zero damage never fires")
		var first := str(int(src.order[0]))
		t.receive_hit(first, 1, 1, Torches.SPARK_DAMAGE)
		check(t.is_lit(first) and t.state.lit.size() == 1, "a single torch lights on its own")
		t.state.pilot_state = 1  # what use() writes (op16 prop61 state1); reach needs the rendered scene
		t.receive_hit("61", 0x2, 1, Torches.SPARK_DAMAGE)
		check(not t.state.pilot_spent, "mask0 without bit0/0x10 is not admitted")
		t.receive_hit("61", 1, 1, Torches.SPARK_DAMAGE)
		check(t.state.pilot_spent and t.state.lit.size() == 35, "Spark at state1: every torch lights (%d)" % t.state.lit.size())
		check(int(t.state.pilot_state) == 1 and host.feedback.size() == 1, "group70 ends at state1 with one message")
		check(Torches.validate(t.checkpoint()).is_empty(), "lit checkpoint valid")
		var saved: Dictionary = t.checkpoint()
		t.receive_hit("61", 1, 1, Torches.SPARK_DAMAGE)
		check(host.feedback.size() == 1 and t.checkpoint() == saved, "one-shot: a second Spark does nothing")
		check(t.restore_checkpoint(Torches.initial()).is_empty() and t.state.lit.is_empty(), "restore to dark")
		check(t.restore_checkpoint(saved).is_empty() and t.state.lit.size() == 35 and t.state.pilot_spent, "restore lit")
	# Long arm: Classic has no closed-passage guard, Enhanced keeps it (owner 2026-10-28).
	Engine.set_meta("lol2_enhanced", false)
	check(not Arm.passage_guard(), "Classic: no passage78 guard")
	var arm: Node3D = Arm.new()
	arm.host = host
	check(arm.refusal() == "", "Classic: closed passage78 does not refuse the axe")
	host.curse = null
	check(arm.refusal() == Arm.NEED_CURSE, "Classic: the stilled-curse refusal stays")
	host.curse = Curse.new()
	Engine.set_meta("lol2_enhanced", true)
	check(Arm.passage_guard() and arm.refusal() == Arm.NEED_PASSAGE, "Enhanced: closed passage78 refuses the axe")
	Engine.set_meta("lol2_enhanced", false)
	arm.free()
	var hints: Array = ArmState.JOURNAL_HINTS
	check(hints.size() == 1 and hints[0].keys().size() == 4 and str(hints[0].hint).length() >= 20 and str(hints[0].hint).find("flag") == -1 and str(hints[0].hint).find("78") == -1, "one in-character My Journal hint for the Long arm")
	var torch_hints: Array = Torches.JOURNAL_HINTS
	check(torch_hints.size() == 1 and torch_hints[0].keys().size() == 4 and str(torch_hints[0].flag) in Torches.initial() and str(torch_hints[0].hint).find("plate") == -1 and str(torch_hints[0].hint).find("61") == -1, "one in-character My Journal hint for the plate-before-Spark order")
	host.queue_free()
	if failures:
		push_error("FAIL: %d museum torch checks" % failures)
		quit(1)
		return
	print("PASS museum torches: plate then Spark lights all 35 torches once, single torches light, save shape strict; Long arm Classic has no passage guard, Enhanced does, one journal hint")
	quit()
