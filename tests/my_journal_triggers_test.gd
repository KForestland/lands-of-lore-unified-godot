extends SceneTree
## Headless, supplied minimal host: the My Journal notes recorded at their planner moment (docs/my-journal.md).
## - Village gate region2443 entered before Shalla's rescue (shared38 clear, no alarm): gate_closed_before_shalla; an
##   admitted entry or the alarm records nothing.
## - Confidante region3408 with neither Daniel known nor Kit'yara dead: no_confidante_yet; with Daniel known nothing.
## - Confidante Met_Confidant (local27) written while the den door was never opened (271): password_known_den_unfound;
##   with 271 set nothing.
## - Museum control181 grants the broken Thohan while Rashar's price is unknown: thohan_sword_broken.
## The den (flags 28/18) and chief's-hut (CHUT_ATTACK) notes are checked on the actual Jungle host in
## thieves_den_room_test and chut_branches_test.
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
const Gate = preload("res://scripts/lol2/jungle_village_gate.gd")
const Confidante = preload("res://scripts/lol2/jungle_confidante.gd")
const Thohan = preload("res://scripts/lol2/museum_broken_thohan.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

class Effects extends Node:
	var data: Dictionary = preload("res://scripts/lol2/player_item_state.gd").initial()
	func state() -> Dictionary: return data
class Magic extends RefCounted:
	func movie_world_active() -> bool: return true
class Host extends Node3D:
	var item_effects: Node
	var quest_state: Dictionary = {"shared_flag_38": 0}
	var village_dialogue = null
	var starting_magic := Magic.new()
	var native_translation := Vector3.ZERO
	var player := CharacterBody3D.new()
	var camera := Camera3D.new()
	var carried_collected: Array = []
	var hand_item := ""
	var flying := false
	var health := 30
	var feedback: Array = []
	func save_feedback(text: String) -> void: feedback.append(text)

func make_host() -> Host:
	var host := Host.new()
	var effects := Effects.new()
	host.item_effects = effects
	host.add_child(effects)
	host.add_child(host.player)
	host.add_child(host.camera)
	root.add_child(host)
	return host

func run() -> void:
	# Village gate.
	var host := make_host()
	var gate: Node3D = Gate.new()
	host.add_child(gate)
	gate.set_physics_process(false)
	check(gate.available, "village gate assets staged")
	host.quest_state.shared_flag_38 = 1
	check(gate.on_entered() and int(gate.state().local24) == 1, "a rescued village admits at the gate")
	check(not "gate_closed_before_shalla" in MyJournal.notes(host), "an admitted entry records no gate note")
	gate.state().local24 = 0
	host.quest_state.shared_flag_38 = 0
	gate.state().shared29 = 1
	check(not gate.on_entered() and not "gate_closed_before_shalla" in MyJournal.notes(host), "the alarm-shut gate records no before-Shalla note")
	gate.state().shared29 = 0
	check(not gate.on_entered() and int(gate.state().local24) == 0, "before the rescue the gate stays shut")
	check("gate_closed_before_shalla" in MyJournal.notes(host), "the gate met before Shalla's rescue records its note")
	host.queue_free()
	# Confidante.
	host = make_host()
	var node: Node3D = Confidante.new()
	host.add_child(node)
	var shared := {"0": 5, "25": 0, "29": 0, "47": 1}
	var ctx := func() -> Dictionary: return {"locals": {"6": 0, "33": 0}, "shared": shared}
	check(Confidante.assets_ready() and node.setup(host, {"context": ctx}).is_empty(), "Confidante setup")
	node._journal_region(3408)
	check(not "no_confidante_yet" in MyJournal.notes(host), "with Daniel known region3408 records nothing")
	shared["47"] = 0
	node._journal_region(3397)
	check(not "no_confidante_yet" in MyJournal.notes(host), "another region records nothing")
	node._journal_region(3408)
	check("no_confidante_yet" in MyJournal.notes(host), "region3408 without Daniel known records the no-Confidante note")
	host.quest_state.thieves_den = {"flags": {"271": 1}}
	node.apply([{"type": "local", "index": 27, "name": "Met_Confidant", "value": 1}])
	check(not "password_known_den_unfound" in MyJournal.notes(host), "with the den door opened the password records nothing")
	host.quest_state.thieves_den.flags["271"] = 0
	node.apply([{"type": "local", "index": 20, "name": "Confidante_trigger_is_active", "value": 1}])
	check(not "password_known_den_unfound" in MyJournal.notes(host), "another local records nothing")
	node.apply([{"type": "local", "index": 27, "name": "Met_Confidant", "value": 1}])
	check("password_known_den_unfound" in MyJournal.notes(host), "Met_Confidant before the den door records the password note")
	host.queue_free()
	# Museum broken Thohan.
	host = make_host()
	var sword: Node3D = Thohan.new()
	host.add_child(sword)
	host.quest_state = {"monastery": {"globals": {"GV_KNOWLEDGE_OF_POWER_ORB": 1}}}
	check(sword.run_source_group() and host.hand_item == Thohan.ITEM, "the broken Thohan is granted")
	check(not "thohan_sword_broken" in MyJournal.notes(host), "with Rashar's price known the grant records nothing")
	check(sword.run_source_group() and host.hand_item == "", "put back")
	host.quest_state.monastery.globals.GV_KNOWLEDGE_OF_POWER_ORB = 0
	check(sword.run_source_group() and "thohan_sword_broken" in MyJournal.notes(host), "the grant before Rashar's price records the broken-sword note")
	host.queue_free()
	if failures:
		push_error("FAIL: %d My Journal trigger checks" % failures)
		quit(1)
		return
	print("PASS My Journal triggers: village gate before Shalla, no Confidante yet, password before the den, broken Thohan; negatives record nothing")
	quit()
