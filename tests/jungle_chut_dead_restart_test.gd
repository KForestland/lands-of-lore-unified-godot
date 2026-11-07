extends SceneTree
const Speech=preload("res://scripts/lol2/monastery_conversation.gd")
var scene
func _initialize() -> void: run.call_deferred()
func run() -> void:
	assert(not has_meta("lol2_jungle_handoff"))
	for stage in ["mid","done"]:
		var path: String="user://tests/chut_dead_"+stage+".json"
		assert(FileAccess.file_exists(path),"Run jungle_chut_dead_test first to create the qualified saves.")
		if is_instance_valid(scene):
			scene.queue_free()
			await process_frame
		scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
		for i in 1500:
			await process_frame
			if scene.ready_for_review:break
		assert(scene.ready_for_review)
		scene.process_mode=Node.PROCESS_MODE_DISABLED
		assert(scene.quickload(path)=="")
		var rooms=scene.monastery
		var s: Dictionary=rooms.state()
		assert(s.room=="CHUT" and s.conversation.sequence=="CHUT_DEAD")
		assert(s.flags["153"]==1 and s.globals.GV_KELSRICK_DEAD==1)
		assert(int(scene.village_gate.state().shared29)==1)
		if stage=="mid":
			assert(s.conversation.cursor==1 and is_equal_approx(s.conversation.elapsed,0.25))
			assert(Speech.active(s.conversation) and rooms.view.clip.line==376)
			rooms.advance(100.0)
		assert(not Speech.active(s.conversation) and s.conversation.cursor==5)
		assert(s.room=="CHUT" and rooms.view.clip.get("idle",false))
		assert(not rooms.chut_first_update())
		rooms.leave_room()
		assert(s.room=="")
		assert(rooms.enter_room("CHUT"))
		rooms.advance(8.0)
		assert(not Speech.active(s.conversation) and s.flags["153"]==1)
	print("PASS new process CHUT death mid-line/completed saves: original line376 resumes, alarm/death/once-only flags persist, finish stays in room and re-entry does not repeat")
	quit()
