extends SceneTree
const Quest=preload("res://scripts/lol2/monastery_quest_state.gd")
const Speech=preload("res://scripts/lol2/monastery_conversation.gd")
var scene
func _initialize() -> void: run.call_deferred()
func run() -> void:
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review:break
	assert(scene.ready_for_review)
	scene.process_mode=Node.PROCESS_MODE_DISABLED
	var rooms=scene.monastery
	var s: Dictionary=rooms.state()
	var media: Array=rooms.view.manifest.rooms.CHUT.sequences.CHUT_DEAD
	assert(media.size()==5)
	for i in 5:
		assert(media[i].line==375+i and media[i].frames==Speech.FRAMES.CHUT_DEAD[i] and media[i].audio_samples==Speech.SAMPLES.CHUT_DEAD[i])
	# Native eight-way admission matrix; flag152 suppresses unrelated peaceful first visit.
	for dead in [0,1]:
		for f150 in [0,1]:
			for f153 in [0,1]:
				s.flags["152"]=1;s.flags["150"]=f150;s.flags["153"]=f153
				s.globals.GV_KELSRICK_DEAD=dead
				s.room="CHUT";s.conversation={"sequence":"CHUT","cursor":1,"elapsed":0.0}
				var starts: bool=dead==1 and f150==0 and f153==0
				assert(rooms.chut_first_update()==starts)
				if starts:
					assert(int(scene.village_gate.state().shared29)==1 and s.flags["153"]==1)
					assert(s.conversation.sequence=="CHUT_DEAD")
	s.flags["150"]=0;s.flags["153"]=0;s.globals.GV_KELSRICK_DEAD=1
	assert(rooms.chut_first_update())
	rooms.restore()
	rooms.advance(Speech.duration("CHUT_DEAD",0)+0.25)
	assert(s.conversation.cursor==1)
	var path: String="user://tests/chut_dead_mid.json"
	assert(scene.quicksave(path)=="")
	assert(scene.quickload(path)=="")
	s=rooms.state()
	assert(s.conversation.sequence=="CHUT_DEAD" and s.conversation.cursor==1 and s.flags["153"]==1)
	rooms.advance(100.0)
	assert(s.room=="CHUT" and not Speech.active(s.conversation))
	assert(rooms.view.clip.get("idle",false))
	assert(not rooms.chut_first_update())
	var bad: Dictionary=s.duplicate(true);bad.flags["153"]=0
	assert(Quest.validate(bad)!="")
	assert(scene.quicksave("user://tests/chut_dead_done.json")=="")
	print("PASS CHUT death:8 native admission cases, original5 clips/timings, alarm-before-speech, mid-line disk reload, no repeat, stays in room")
	quit()
