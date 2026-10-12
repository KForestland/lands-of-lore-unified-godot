extends SceneTree
func _initialize(): run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func run():
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	root.grab_focus()
	await process_frame
	scene.departure.set_process(false)
	if not check(scene.quickload("user://tests/act1_departure_ready.json").is_empty(),"Exit fixture unavailable"): return
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for tick in range(10):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	# Explicit local branch fixtures; these are not earned progress.
	var state: Dictionary = scene.area_handoff()
	state.quests.monastery.globals.GV_RUNES_TRANSLATED = 0
	state.quests.monastery.globals.GV_HAS_RUNES = 0
	state.quests.act_one_departure = {"local55":2,"phase":"idle","elapsed":0.0}
	if not check(scene.apply_area_handoff(state).is_empty() and not scene.departure.begin(),"Local55==2 was admitted"): return
	state.quests.act_one_departure.local55 = 0
	if not check(scene.apply_area_handoff(state).is_empty() and scene.departure.begin() and scene.departure.state().phase=="movie","First use invented a rune-completion gate"): return
	state.quests.act_one_departure = {"local55":1,"phase":"arrived","elapsed":0.0}
	if not check(scene.apply_area_handoff(state).is_empty() and scene.departure.state().phase=="idle","Return to source area did not rearm repeat exit"): return
	if not check(scene.departure.begin() and scene.departure.state().phase=="arrival" and not scene.departure.voice.playing,"Repeat exit played movie"): return
	scene.departure.set_process(true)
	for tick in range(180):
		await process_frame
		if is_instance_valid(current_scene) and current_scene != scene: break
	if not check(is_instance_valid(current_scene) and current_scene.scene_file_path=="res://scenes/lol2/darker_jungle.tscn","Repeat exit did not load destination"): return
	scene = current_scene
	if not check(scene.quest_state.monastery.globals.GV_RUNES_TRANSLATED==0,"Repeat fixture acquired invented translation"): return
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	await process_frame
	await physics_frame
	await process_frame
	if not check(hive.apply_area_handoff(scene.area_handoff()).is_empty() and hive.area_handoff().quests.act_one_departure.local55==1,"Hive dropped Huline departure local"): return
	var path := "user://tests/hive_departure_carry.json"
	if not check(hive.quicksave(path).is_empty() and hive.quickload(path).is_empty() and hive.area_handoff().quests.act_one_departure.phase=="arrived","Hive disk lost departure state"): return
	hive.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: invalid local rejected, no invented rune gate, repeat skips movie, source rearm and Hive disk carry")
	quit()
