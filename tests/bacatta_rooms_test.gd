extends SceneTree
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
func _initialize(): run.call_deferred()
func run():
	var path := "user://tests/bacatta_%d.json" % Time.get_ticks_usec()
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	var rooms = jungle.monastery
	rooms.set_process(false)
	for sequence in ["VILLAGE","CAN","CAN_EXIT"]:
		var room := Speech.room_for(sequence)
		var bank := "exit_movies" if sequence == "CAN_EXIT" else "movies"
		var clips: Array = rooms.view.manifest.rooms[room][bank]
		for i in range(clips.size()):
			assert(clips[i].frames == Speech.FRAMES[sequence][i])
			assert(clips[i].audio_samples == Speech.SAMPLES[sequence][i])
			assert(is_equal_approx(clips[i].duration,Speech.duration(sequence,i)))
	# Initial location is supplied; normal region detection starts the village intro.
	jungle.player.position = Vector3(-1630,32,-3900)
	rooms._process(0.0)
	assert(rooms.state().room == "VILLAGE" and Speech.active(rooms.state().conversation))
	assert(not rooms.enter_room("CAN"))
	rooms.advance(0.8)
	assert(jungle.quicksave(path).is_empty())
	rooms.advance(2.0)
	assert(jungle.quickload(path).is_empty() and rooms.view.last_frame == 12)
	rooms.advance(1000)
	assert(rooms.state().flags["41"] == 1 and rooms.state().globals.GV_MET_BACATTA == 0)
	rooms.state().flags["267"] = 1
	assert(not rooms.enter_room("CAN"))
	rooms.state().flags["267"] = 0
	assert(rooms.enter_room("CAN"))
	assert(rooms.state().globals.GV_MET_BACATTA == 1 and rooms.state().flags["45"] == 1)
	rooms.advance(Speech.duration("CAN",0)+Speech.duration("CAN",1)+0.5)
	assert(rooms.state().conversation.cursor == 2 and rooms.view.clip.frames == 0)
	assert(rooms.view.visual.frames == 109 and rooms.view.voice.playing)
	assert(jungle.quicksave(path).is_empty())
	rooms.advance(3.0)
	assert(jungle.quickload(path).is_empty())
	assert(rooms.state().conversation.cursor == 2 and is_equal_approx(rooms.state().conversation.elapsed,0.5))
	rooms.advance(1000)
	assert(rooms.state().flags["32"] == 1 and rooms.state().flags["33"] == 1 and rooms.state().flags["37"] == 1)
	assert(rooms.view.clip.get("idle",false))
	rooms.leave_room()
	assert(rooms.state().conversation.sequence == "CAN_EXIT" and rooms.state().room == "CAN")
	assert(rooms.state().flags["34"] == 1 and rooms.state().flags["37"] == 0)
	rooms.advance(0.2)
	assert(jungle.quicksave(path).is_empty())
	rooms.advance(1000)
	assert(rooms.state().room == "VILLAGE")
	assert(jungle.quickload(path).is_empty() and rooms.state().room == "CAN")
	rooms.advance(1000)
	assert(rooms.state().room == "VILLAGE")
	rooms.leave_room()
	assert(not rooms.active() and jungle.is_physics_processing())
	rooms._process(0.0)
	assert(not rooms.active()) # exiting inside the source trigger must not reopen it
	# The inter-area walk is a separate check; move only the fixture, never its flags.
	jungle.player.position = Vector3(4250,42,2377)
	rooms.was_inside = false
	rooms._process(0.0)
	assert(rooms.state().room == "MENT")
	assert(rooms.enter_room("MLIB"))
	assert(Speech.active(rooms.state().conversation) and rooms.state().locals.Met_Dawn == 1)
	rooms.advance(1000)
	rooms.leave_room()
	assert(rooms.enter_room("MOFF"))
	rooms.advance(1000)
	assert(jungle.carried_collected.count(Speech.FLUTE) == 1)
	assert(jungle.quicksave(path).is_empty())
	assert(jungle.quickload(path).is_empty() and jungle.carried_collected.count(Speech.FLUTE) == 1)
	await process_frame
	await process_frame
	if "--capture-bacatta" in OS.get_cmdline_user_args():
		rooms.state().room = "CAN"
		rooms.restore()
		await create_timer(0.25).timeout
		root.get_texture().get_image().save_png("res://tmp/bacatta_room.png")
	jungle.free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(path)
	print("PASS: village intro, earned Bacatta prerequisite, audio-only resume, farewell/save return and Dawn/Julian flute chain; two supplied area positions")
	quit()
