extends SceneTree
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
const Save = preload("res://scripts/lol2/jungle_save.gd")
func _initialize(): run.call_deferred()
func run():
	var path := "user://tests/monastery_%d.json" % Time.get_ticks_usec()
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	var rooms = jungle.monastery
	rooms.set_process(false)
	# Supplied location only: use the ordinary region detector to enter MENT.
	jungle.player.position = Vector3(4250,42,2377)
	rooms._process(0.0)
	assert(rooms.active() and rooms.state().room == "MENT" and not jungle.is_physics_processing())
	await process_frame
	await process_frame
	assert(rooms.view.background.is_playing())
	assert(not rooms.enter_room("MOFF"))
	assert(rooms.enter_room("MLIB"))
	assert(not Speech.active(rooms.state().conversation))
	assert(rooms.state().locals.Met_Dawn == 0)
	rooms.leave_room()
	# Bacatta gameplay is still separate; this is an explicit prerequisite fixture.
	rooms.state().globals.GV_MET_BACATTA = 1
	assert(rooms.enter_room("MLIB"))
	assert(Speech.active(rooms.state().conversation) and rooms.view.voice.playing)
	rooms.advance(0.8)
	assert(jungle.quicksave(path).is_empty())
	var invalid: Dictionary = Save.read_save(path).state
	invalid.quests.monastery.room = "MENT"
	assert(not jungle.apply_save(invalid).is_empty())
	assert(rooms.state().room == "MLIB" and is_equal_approx(rooms.state().conversation.elapsed,0.8))
	rooms.advance(3)
	assert(jungle.quickload(path).is_empty())
	assert(is_equal_approx(rooms.state().conversation.elapsed,0.8))
	assert(rooms.shown_cursor == 0 and rooms.view.last_frame == 12)
	rooms.advance(1000)
	assert(rooms.state().flags["182"] == 1 and rooms.state().flags["183"] == 1)
	rooms.leave_room()
	assert(rooms.enter_room("MOFF"))
	assert(rooms.state().flags["134"] == 1)
	var before_grant := 0.0
	for i in range(20): before_grant += Speech.duration("MOFF",i)
	rooms.advance(before_grant+1.0)
	assert(not Speech.FLUTE in jungle.carried_collected)
	assert(rooms.state().conversation.cursor == 20)
	assert(jungle.quicksave(path).is_empty())
	rooms.advance(Speech.duration("MOFF",20)-0.9)
	assert(Speech.FLUTE in jungle.carried_collected and rooms.state().flags["138"] == 1)
	assert(jungle.quickload(path).is_empty())
	assert(not Speech.FLUTE in jungle.carried_collected and rooms.state().flags["138"] == 0)
	rooms.advance(Speech.duration("MOFF",20)-0.9)
	assert(jungle.carried_collected.count(Speech.FLUTE) == 1)
	assert(jungle.quicksave(path).is_empty())
	rooms.advance(1000)
	assert(jungle.quickload(path).is_empty())
	rooms.advance(1000)
	assert(jungle.carried_collected.count(Speech.FLUTE) == 1)
	rooms.leave_room()
	assert(Speech.active(rooms.state().conversation))
	rooms.advance(1000)
	assert(rooms.state().room == "MENT")
	rooms.leave_room()
	assert(not rooms.active() and jungle.is_physics_processing())
	assert(jungle.player.position.x == 4181 and jungle.player.position.z == 2377)
	assert(Save.validate_inventory(jungle.inventory_state()).is_empty())
	var handoff: Dictionary = jungle.area_handoff()
	jungle.free()
	await process_frame
	await process_frame
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	await process_frame
	await process_frame
	assert(hive.apply_area_handoff(handoff).is_empty())
	assert(Speech.FLUTE in hive.carried_inventory.collected)
	assert(hive.area_handoff().quests.monastery.flags["138"] == 1)
	hive.free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(path)
	await process_frame
	print("PASS: monastery source-region entry, prerequisite gates, speech disk resume, timed flute grant/rollback, return and Hive carry; Bacatta flag supplied")
	quit()
