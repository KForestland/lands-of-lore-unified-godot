extends SceneTree
const State = preload("res://scripts/lol2/monastery_quest_state.gd")
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
func _initialize(): run.call_deferred()
func run():
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/monastery_side_rooms.json"))
	for case in fixture.cases:
		var s := State.initial()
		s.flags.merge(case.flags,true)
		s.globals.merge(case.get("globals",{}),true)
		s.locals.merge(case.get("locals",{}),true)
		assert(State.side_actor_present(s,case.room) == case.present)
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	var rooms = jungle.monastery
	rooms.set_process(false)
	assert(rooms.enter_room("MENT"))
	assert(not rooms.enter_room("MCEL"))
	assert(rooms.enter_room("MGAR"))
	assert(rooms.state().conversation.sequence == "MGAR" and rooms.state().locals.Met_Morgan == 1)
	assert(rooms.state().flags["258"] == 1 and rooms.state().flags["176"] == 0)
	await process_frame
	await process_frame
	assert(rooms.view.background.is_playing() and rooms.view.voice.playing)
	rooms.advance(Speech.duration("MGAR",0)+0.1)
	var path := "user://tests/monastery_side_%d.json" % Time.get_ticks_usec()
	assert(jungle.quicksave(path).is_empty())
	rooms.advance(1000)
	assert(rooms.state().flags["176"] == 1 and rooms.state().flags["177"] == 1 and rooms.state().flags["178"] == 1)
	assert(jungle.quickload(path).is_empty())
	assert(rooms.state().conversation.cursor == 1 and rooms.state().flags["176"] == 0)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not jungle.is_physics_processing())
	rooms.advance(1000)
	rooms.leave_room()
	assert(rooms.enter_room("MGAR") and rooms.state().conversation.sequence == "MGAR_REPEAT")
	rooms.advance(1000)
	assert(rooms.state().flags["260"] == 1)
	rooms.leave_room()
	assert(rooms.enter_room("MGAR") and not rooms.state().side_actor_present)
	assert(not Speech.active(rooms.state().conversation) and rooms.view.patch.texture == null)
	rooms.leave_room()
	# Admission prerequisites are supplied here; earned visits are a separate route check.
	rooms.state().flags["134"] = 1
	rooms.state().locals.Met_Dawn = 1
	assert(rooms.enter_room("MCEL") and rooms.state().conversation.sequence == "MCEL")
	assert(rooms.state().side_actor_present and rooms.state().flags["170"] == 1 and rooms.state().flags["171"] == 1)
	rooms.advance(Speech.duration("MCEL",0)+0.2)
	assert(jungle.quicksave(path).is_empty())
	rooms.advance(1000)
	rooms.leave_room()
	assert(rooms.enter_room("MCEL") and not rooms.state().side_actor_present)
	assert(jungle.quickload(path).is_empty())
	assert(rooms.state().side_actor_present and rooms.state().conversation.cursor == 1)
	rooms.advance(1000)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://tmp/act1_team_20260927/monastery_cellar_live.png")
	rooms.leave_room()
	rooms.leave_room()
	assert(jungle.is_physics_processing())
	jungle.queue_free()
	await process_frame
	await process_frame
	print("PASS:40 native actor-admission cases; garden/cellar original dialogue, repeat/absence, flags and partial disk saves")
	quit()
