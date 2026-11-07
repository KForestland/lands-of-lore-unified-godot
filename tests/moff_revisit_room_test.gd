extends SceneTree
## Julian's office through the real room layer: translated revisit 600-604, exit
## 564-567 with the orb granted after 566, disk rollback and return to MENT.
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
var failures := 0
func _initialize(): run.call_deferred()
func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: "+label)
func orb_count(scene) -> int:
	return scene.carried_collected.count(Speech.ORB)+scene.monastery.state().get("pending_items",[]).count(Speech.ORB)
func run():
	var path := "user://tests/moff_revisit_%d.json" % Time.get_ticks_usec()
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var rooms = scene.monastery
	rooms.set_process(false)
	# Supplied post-translation monastery state (the earned chain produces the same flags).
	var s: Dictionary = rooms.state()
	s.locals.Met_Dawn = 1
	for key in ["134","135","136","138","140","141","142","145","283"]: s.flags[key] = 1
	s.globals.GV_HAS_RUNES = 1
	s.globals.GV_RUNES_TRANSLATED = 1
	check(rooms.enter_room("MENT") and rooms.enter_room("MOFF"),"office did not open")
	s = rooms.state()
	check(s.conversation.sequence == "MOFF_TRANSLATED" and s.moff_load.translated == 1,"translated revisit did not start")
	await process_frame
	check(str(rooms.view.clip.get("name","")).contains("2260007E"),"original 600 clip not shown")
	rooms.leave_room()
	check(s.room == "MOFF","left while Julian was speaking")
	rooms.advance(60.0)
	check(s.flags["288"] == 1 and not Speech.active(s.conversation),"600-604 did not finish/set 288")
	rooms.leave_room()
	check(s.conversation.sequence == "MOFF_EXIT_ORB" and s.flags["148"] == 1 and s.flags["146"] == 1 and s.room == "MOFF","orb exit did not start")
	await process_frame
	check(str(rooms.view.clip.get("name","")).contains("2256407E"),"original 564 clip not shown")
	rooms.advance(Speech.duration("MOFF_EXIT_ORB",0)+0.1)
	check(orb_count(scene) == 0 and scene.quicksave(path).is_empty(),"mid-exit save failed or orb early")
	rooms.advance(Speech.duration("MOFF_EXIT_ORB",1)+Speech.duration("MOFF_EXIT_ORB",2))
	check(orb_count(scene) == 1 and scene.quest_state.monastery.globals.GV_KNOWLEDGE_OF_POWER_ORB == 1 and s.room == "MOFF","grant after 566 missing")
	check(scene.quickload(path).is_empty(),"quickload failed")
	rooms = scene.monastery
	s = rooms.state()
	check(orb_count(scene) == 0 and int(s.conversation.cursor) == 1 and s.room == "MOFF","disk rollback lost partial exit")
	rooms.advance(100.0)
	check(orb_count(scene) == 1 and s.room == "MENT" and not Speech.active(s.conversation),"exit did not finish at MENT with one orb")
	check(not rooms.enter_room("MOFF"),"office admitted after flag288")
	rooms.leave_room()
	check(not rooms.active(),"MENT did not return to the Jungle")
	scene.queue_free()
	await process_frame
	await process_frame
	if failures:
		push_error("FAIL: %d office room checks" % failures)
		quit(1)
		return
	print("PASS: office translated revisit, source exit with delayed orb grant, mid-exit disk rollback and MENT return")
	quit()
