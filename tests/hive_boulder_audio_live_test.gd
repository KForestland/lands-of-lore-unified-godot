extends SceneTree
const Audio=preload("res://scripts/lol2/hive_boulder_audio_state.gd")
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if ok: return true
	push_error(message)
	quit(1)
	return false
func freeze() -> void:
	for node in [scene,scene.curse,scene.hive_curse,scene.boulder_surfaces,scene.boulders,scene.boulder_audio]: node.set_physics_process(false)
func step(count: int) -> void:
	for i in range(count):
		await physics_frame
		var delta: float=scene.player.get_physics_process_delta_time()
		scene.move_grounded(Vector3.ZERO,delta)
		scene.boulder_surfaces._physics_process(delta)
		scene.boulders._physics_process(delta)
		scene.boulder_audio._physics_process(delta)
func same(a: Dictionary,b: Dictionary) -> bool:
	for key in Audio.LENGTHS:
		if absf(a.clocks[key]-b.clocks[key])>0.000000001: return false
	return true
func run() -> void:
	Engine.time_scale=4
	Engine.physics_ticks_per_second=240
	scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	freeze()
	var audio=scene.boulder_audio
	if not check(audio.players.size()==4 and audio.checkpoint()==Audio.initial(),"Dormant audio played before the source trigger"): return
	scene.player.position=Vector3(-2230,-1355,-6720)
	for i in range(120):
		await step(1)
		if scene.boulder_surfaces.state.phase==1: break
	if not check(audio.players.close.playing and not audio.players.exit.playing,"Close cue did not start alone"): return
	# Simulate the mixer finishing before the physics clock: no tail replay.
	audio.players.close.stop()
	audio.present()
	if not check(not audio.players.close.playing,"One-shot mixer completion replayed its tail"): return
	if not check(audio.restore(audio.checkpoint()).is_empty() and audio.players.close.playing,"Explicit restore failed to resume close cue"): return
	for i in range(120):
		await step(1)
		if scene.boulders.state.actors["30"].rolling: break
	if not check(audio.players["30"].playing and audio.players["31"].playing,"Owner rolling sounds did not start"): return
	await step(7)
	var path:="user://tests/hive_boulder_audio_midroll.json"
	if not check(scene.quicksave(path).is_empty(),"Audio midroll save rejected"): return
	var saved: Dictionary=audio.checkpoint()
	var handoff: Dictionary=scene.area_handoff()
	await step(17)
	var continued: Dictionary=audio.checkpoint()
	if not check(scene.quickload(path).is_empty(),"Audio midroll load rejected"): return
	freeze()
	if not check(same(saved,audio.checkpoint()) and audio.players["30"].playing,"Audio restore lost the saved clock or voice"): return
	await step(17)
	if not check(same(continued,audio.checkpoint()),"Resumed audio clock diverged"): return
	var stable: Dictionary=audio.checkpoint()
	paused=true
	audio._process(0)
	audio._physics_process(3)
	if not check(same(stable,audio.checkpoint()) and audio.players["30"].stream_paused,"Pause advanced or played rolling audio"): return
	paused=false
	audio._process(0)
	if not check(not audio.players["30"].stream_paused,"Unpause failed to resume owned voice"): return
	Engine.time_scale=0
	audio._process(0)
	if not check(audio.players["30"].stream_paused,"Zero time scale left live audio running"): return
	Engine.time_scale=4
	audio._process(0)
	var bad: Dictionary=scene.area_handoff()
	bad.quests.hive_boulder_audio.clocks.erase("31")
	if not check(not scene.apply_area_handoff(bad).is_empty() and same(stable,audio.checkpoint()) and audio.players["30"].playing,"Malformed audio mutated active playback"): return
	bad=scene.area_handoff()
	bad.quests.erase("hive_boulder_audio")
	if not check(not scene.apply_area_handoff(bad).is_empty(),"New missing audio packet accepted as legacy"): return
	for i in range(1100):
		await step(1)
		if scene.boulder_surfaces.state.phase==3 and scene.boulder_surfaces.state.elapsed==2: break
	if not check(audio.players.exit.playing and Audio.active(audio.state,"exit"),"Surface cap cut the original exit sound tail"): return
	if not check(not audio.players["30"].playing and not audio.players["31"].playing,"Stopped owners kept rolling sounds"): return
	var tail_path:="user://tests/hive_boulder_audio_exit_tail.json"
	if not check(scene.quicksave(tail_path).is_empty(),"Exit-tail save failed"): return
	await step(15)
	if not check(not audio.players.exit.playing,"Exit cue did not finish"): return
	if not check(scene.quickload(tail_path).is_empty() and audio.players.exit.playing,"Exit-tail load did not restore unfinished audio"): return
	freeze()
	await step(15)
	if not check(not audio.players.exit.playing,"Restored exit cue repeated"): return
	var legacy: Dictionary=scene.area_handoff()
	legacy.quests.erase("hive_boulder_audio")
	legacy.quests.erase("hive_boulder_audio_schema")
	if not check(scene.apply_area_handoff(legacy).is_empty() and not audio.players.close.playing and not audio.players.exit.playing,"Legacy settled trap replayed old cues"): return
	scene.queue_free()
	await process_frame
	await physics_frame
	var jungle=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	current_scene=jungle
	await process_frame
	await physics_frame
	jungle.set_physics_process(false)
	if not check(jungle.apply_area_handoff(handoff).is_empty(),"Jungle rejected saved boulder audio"): return
	if not check(jungle.quicksave("user://tests/boulder_audio_jungle.json").is_empty() and jungle.quickload("user://tests/boulder_audio_jungle.json").is_empty(),"Jungle audio disk roundtrip failed"): return
	if not check(same(jungle.area_handoff().quests.hive_boulder_audio,saved),"Jungle changed audio clocks"): return
	jungle.queue_free()
	await process_frame
	print("PASS original close/rolling/exit streams, saved midroll and exit tail, owner stop, pause, malformed rollback, legacy no replay and Jungle disk transport")
	quit()
