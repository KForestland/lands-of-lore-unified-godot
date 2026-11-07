extends SceneTree
const Hints = preload("res://scripts/lol2/act3_journal_hints.gd")
const MyJournal = preload("res://scripts/lol2/my_journal.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

class Effects:
	extends Node
	var data: Dictionary = {"journal": []}
	func state() -> Dictionary:
		return data

class Host:
	extends Node3D
	var area_id := ""
	var quest_state: Dictionary = {}
	var player: Node3D
	var item_effects: Node
	func save_feedback(_text: String) -> void:
		pass

func make(area: String) -> Host:
	var host := Host.new()
	host.area_id = area
	var effects := Effects.new()
	host.item_effects = effects
	host.add_child(effects)
	var player := Node3D.new()
	host.player = player
	host.add_child(player)
	root.add_child(host)
	return host

func marker(host: Host, node_name: String) -> void:
	var mark := Node.new()
	mark.name = node_name
	host.add_child(mark)

func run() -> void:
	for row in Hints.JOURNAL_HINTS:
		var text := str(row.hint)
		check(text.length() >= 20 and text.length() <= 130, "length %s %d" % [row.when, text.length()])
		check(MyJournal.hints().has(row.when), "registered %s" % row.when)
	check(MyJournal.hints().size() == 45, "45 notes")
	var quiet := make("L8_SJ")
	var skipped: Node = Hints.attach(quiet)
	check(skipped == null and quiet.get_node_or_null("Act3JournalHints") == null, "other areas stay quiet")
	quiet.free()
	_fountain()
	_cavern()
	_horn()
	_sewer()
	_heads()
	_curse()
	if failures == 0:
		print("PASS act3 journal: six notes, fired beside the hosted nodes")
	quit(1 if failures else 0)

func _fountain() -> void:
	var host := make("L16_CA")
	marker(host, "L16DryFountain")
	var node: Node = Hints.attach(host)
	host.player.position = Hints.FOUNTAIN_AT
	node.check()
	check(MyJournal.notes(host) == ["l16_south_fountain"], "fountain note")
	node.check()
	check(MyJournal.notes(host).size() == 1, "fountain once")
	host.free()
	host = make("L16_CA")
	marker(host, "L16DryFountain")
	node = Hints.attach(host)
	host.player.position = Hints.FOUNTAIN_AT + Vector3(0, 0, 801)
	host.quest_state = {"l16_dry_fountain": {"broken": false}}
	node.check()
	check(MyJournal.notes(host).is_empty(), "fountain radius")
	host.player.position = Hints.FOUNTAIN_AT
	host.quest_state = {"l16_dry_fountain": {"broken": true}}
	node.check()
	check(MyJournal.notes(host).is_empty(), "broken ball stays quiet")
	host.free()

func _cavern() -> void:
	var host := make("L17_HC")
	marker(host, "L17CavernRun")
	var node: Node = Hints.attach(host)
	host.player.position = Hints.CAVERN_AT
	node.check()
	check(MyJournal.notes(host) == ["l17_cavern_exit"], "cavern note")
	host.free()
	host = make("L17_HC")
	marker(host, "L17CavernRun")
	node = Hints.attach(host)
	host.player.position = Hints.CAVERN_AT
	host.quest_state = {"l17_cavern_run": {"exit_region": 1}}
	node.check()
	check(MyJournal.notes(host).is_empty(), "exit already chosen")
	host.free()

func _horn() -> void:
	var host := make("L19_BC")
	marker(host, "L19BelialHorn")
	var node: Node = Hints.attach(host)
	host.player.position = Hints.HORN_AT
	node.check()
	check(MyJournal.notes(host) == ["l19_horn_keep"], "horn note")
	host.free()
	host = make("L19_BC")
	marker(host, "L19BelialHorn")
	node = Hints.attach(host)
	host.player.position = Hints.HORN_AT
	host.quest_state = {"l19_belial_horn": {"taken": true}}
	node.check()
	check(MyJournal.notes(host).is_empty(), "horn already taken")
	host.free()

func _sewer() -> void:
	var host := make("L19_BC")
	marker(host, "L19SewerForms")
	var node: Node = Hints.attach(host)
	host.player.position = Hints.SEWER_AT
	host.quest_state = {"l19_sewer_forms": {"switches": [74.0, 75.0]}}
	node.check()
	check(MyJournal.notes(host) == ["l19_sewer_cross"], "two switches still open")
	host.free()
	host = make("L19_BC")
	marker(host, "L19SewerForms")
	node = Hints.attach(host)
	host.player.position = Hints.SEWER_AT
	host.quest_state = {"l19_sewer_forms": {"switches": [74, 75, 76]}}
	node.check()
	check(MyJournal.notes(host).is_empty(), "three switches stay quiet")
	host.free()

func _heads() -> void:
	var host := make("L19_BC")
	marker(host, "L19GhostlyHeads")
	var node: Node = Hints.attach(host)
	host.player.position = Hints.HEADS_AT[2]
	node.check()
	check(MyJournal.notes(host) == ["l19_ghostly_heads"], "near any head")
	host.free()
	host = make("L19_BC")
	marker(host, "L19GhostlyHeads")
	node = Hints.attach(host)
	host.player.position = Vector3.ZERO
	host.quest_state = {"l19_ghostly_heads": {"shot": [67, 69, 68, 70]}}
	node.check()
	check(MyJournal.notes(host).is_empty(), "four shots stay quiet")
	host.free()

func _curse() -> void:
	var host := make("L19_BC")
	marker(host, "L19DawnCurse")
	var node: Node = Hints.attach(host)
	host.player.position = Hints.DAWN_AT
	node.check()
	check(MyJournal.notes(host) == ["l19_curse_mother"], "dawn curse note")
	host.free()
	host = make("L20_BB")
	marker(host, "L20MotherCurse")
	node = Hints.attach(host)
	host.player.position = Hints.MOTHER_AT
	host.quest_state = {"l19_dawn_curse": {"curse_said": false}}
	node.check()
	check(MyJournal.notes(host) == ["l19_curse_mother"], "mother curse note")
	host.free()
	host = make("L20_BB")
	marker(host, "L20MotherCurse")
	node = Hints.attach(host)
	host.player.position = Hints.MOTHER_AT
	host.quest_state = {"l19_dawn_curse": {"curse_said": true}}
	node.check()
	check(MyJournal.notes(host).is_empty(), "curse already said")
	host.free()
