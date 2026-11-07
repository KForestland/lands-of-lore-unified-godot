extends SceneTree
const Journey = preload("res://scripts/lol2/l8_journey.gd")
const State = preload("res://scripts/lol2/l8_journey_state.gd")
const Save = preload("res://scripts/lol2/act2_save.gd")
class TestHost extends Node3D:
	var quest_state := preload("res://scripts/lol2/act_one_quest_state.gd").initial()
	var carried_collected: Array = [State.BLADE]
	var equipped_item := State.BLADE
	var player := Node3D.new()
	var native_translation := Vector3.ZERO
	func _ready(): add_child(player)
var failures := 0
func check(ok: bool, message: String):
	if not ok: failures+=1; printerr("FAIL L8 binding: ",message)
func _initialize(): run.call_deferred()
func run():
	var host := TestHost.new()
	root.add_child(host)
	var journey := Journey.new()
	journey.host = host
	host.add_child(journey)
	var path := "res://tmp/l8_journey_save_test.json"
	host.player.position = Vector3.ZERO
	check(not journey.interact("offer_daniel",State.BLADE).ok,"remote action refused")
	var steps := [["entry","offer_daniel"],["entry","hopper_interruption"],["entry","recover_blade"],["temple","visit_temple"],["village","show_guard"],["village","offer_daniel"],["village","visit_shaman"]]
	for step in steps:
		host.player.position = Journey.TARGETS[step[0]]
		var result := journey.interact(step[1],State.BLADE)
		check(result.ok,"bound action " + step[1])
		var packet := {"format":"l8-journey-test","version":1,"inventory":{"collected":host.carried_collected.duplicate(),"equipped_item":host.equipped_item,"equipped_armor":""},"quests":host.quest_state.duplicate(true),"player":{"position":[0,32,0],"yaw":0,"pitch":0}}
		var error := Save.write_save(path,packet,"l8-journey-test")
		check(error.is_empty(),"actual save after " + step[1] + ": " + error)
		if not error.is_empty():
			host.queue_free()
			quit(1)
			return
		var loaded := Save.read_save(path,"l8-journey-test")
		check(loaded.error.is_empty(),"reload " + step[1])
		host.quest_state = loaded.state.quests
		host.carried_collected = loaded.state.inventory.collected
		host.equipped_item = loaded.state.inventory.equipped_item
	check(host.carried_collected.count(State.KEY)==1,"one key after persisted sequence")
	check(not journey.interact("visit_shaman").ok,"duplicate shaman reward refused")
	var prior := FileAccess.get_file_as_string(path)
	var bad: Dictionary = Save.read_save(path,"l8-journey-test").state
	bad.quests.l8_journey.temple_visited = false
	check(not Save.write_save(path,bad,"l8-journey-test").is_empty(),"corrupt history refused")
	check(FileAccess.get_file_as_string(path)==prior,"refused save preserves previous file")
	DirAccess.remove_absolute(path)
	host.queue_free()
	await process_frame
	if failures==0: print("PASS L8 bound semantic actions and actual save/reload; production map walk/render still pending")
	quit(0 if failures==0 else 1)
