extends SceneTree
const State = preload("res://scripts/lol2/jungle_village_state.gd")
const Quests = preload("res://scripts/lol2/act_one_quest_state.gd")
var scene
var path := "user://tests/jungle_village_%d.json" % Time.get_ticks_usec()
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, message: String) -> bool:
	if value: return true
	push_error(message)
	DirAccess.remove_absolute(path)
	quit(1)
	return false
func settle(position: Vector3) -> void:
	scene.player.position = position
	scene.player.velocity = Vector3.ZERO
	for i in range(45):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,1.0/60.0)
func walk(direction: Vector3, count: int) -> void:
	for i in range(count):
		await physics_frame
		scene.move_grounded(direction,1.0/60.0)
func run() -> void:
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/jungle-village-source.json"))
	for row in proof.cases:
		if not check(State.admits(int(row[0]),{"shared29":row[1],"local24":row[2]}) == bool(row[3]),"Native village predicate differs"): return
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_physics_process(false)
	scene.village_dialogue.set_process(false)
	var gate = scene.village_gate
	gate.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not check(not scene.village_dialogue.begin(),"Speech began before gate admission"): return
	if not check(gate.available and gate.pose == 0,"Original gate assets missing"): return
	await settle(Vector3(-1300,34,-5250))
	if not check(scene.player.is_on_floor() and gate.inside(),"Gate approach failed to ground inside source region2443"): return
	gate.was_inside = false
	if not check(not gate.check_contact() and gate.state().local24 == 0,"Village admitted before rescue"): return
	await walk(Vector3.LEFT,100)
	if not check(scene.player.position.x > -1365 and scene.player.position.x < -1350,"Closed original gate did not block ordinary movement: %s" % scene.player.position): return
	# A source-consistent completed rescue checkpoint, not an end-to-end quest fixture.
	scene.quest_state.shared_flag_38 = 1
	scene.quest_state.hive_room_entered = true
	scene.quest_state.conversation = {"started":true,"completed":true,"section_cursor":3,"elapsed":Quests.DURATIONS[3]}
	await settle(Vector3(-1300,34,-5250))
	gate.state().shared29 = 1
	gate.was_inside = false
	if not check(not gate.check_contact(),"Shared29 restriction ignored"): return
	gate.state().shared29 = 0
	gate.was_inside = false
	if not check(gate.check_contact() and gate.state().local24 == 1,"Rescued village entry did not latch source local24"): return
	var speech = scene.village_dialogue
	if not check(speech.active() and speech.audio.playing,"Admission did not play original speech"): return
	var before: Vector3 = scene.player.position
	await walk(Vector3.LEFT,20)
	if not check(scene.player.position.distance_to(before)<0.1,"Speech failed to lock walking"): return
	speech.advance(6.0)
	if not check(speech.frame == 90 and speech.state().local15 == 0,"Partial speech frame/completion wrong"): return
	paused = true
	speech.advance(10)
	paused = false
	speech.advance(-10)
	if not check(speech.frame == 90,"Pause or negative delta advanced speech"): return
	gate.advance(0.6)
	if not check(gate.pose == 50 and is_equal_approx(gate.state().elapsed,0.6),"Gate failed halfway motion"): return
	if not check(scene.quicksave(path).is_empty(),"Gate checkpoint write failed"): return
	var saved: Dictionary = scene.Save.read_save(path)
	var bytes := FileAccess.get_file_as_bytes(path)
	var impossible: Dictionary = saved.state.duplicate(true)
	impossible.quests.jungle_village.dialogue.local15 = 1
	if not check(not scene.apply_save(impossible).is_empty(),"Incomplete speech accepted completion flag"): return
	impossible = saved.state.duplicate(true)
	impossible.quests.jungle_village.dialogue.local46 = 1
	if not check(not scene.apply_save(impossible).is_empty(),"Killed villager accepted normal speech"): return
	for bad in [NAN,INF,-1.0,28.0,true,"bad"]:
		var invalid: Dictionary = saved.state.duplicate(true)
		invalid.quests.jungle_village.dialogue.elapsed = bad
		if not check(not scene.apply_save(invalid).is_empty() and speech.frame == 90,"Invalid dialogue mutated scene"): return
		if not check(not scene.Save.write_save(path,invalid).is_empty() and FileAccess.get_file_as_bytes(path)==bytes,"Invalid dialogue replaced save"): return
	for bad in [NAN,INF,-1.0,2.0,true,"bad"]:
		var invalid: Dictionary = saved.state.duplicate(true)
		invalid.quests.jungle_village.elapsed = bad
		if not check(not scene.apply_save(invalid).is_empty() and gate.pose == 50,"Invalid gate save mutated scene"): return
		if not check(not scene.Save.write_save(path,invalid).is_empty() and FileAccess.get_file_as_bytes(path)==bytes,"Invalid gate save replaced file"): return
	paused = true
	gate.advance(1)
	if not check(gate.pose == 50,"Paused gate advanced"): return
	paused = false
	gate.advance(-1)
	if not check(gate.pose == 50,"Negative delta rewound gate"): return
	# Put the body in the future swing, clear of the halfway leaf. Opening must
	# stop conservatively, then continue after the body leaves the sweep.
	scene.player.position = Vector3(-1440,32,-5310)
	await physics_frame
	gate.advance(0.6)
	if not check(gate.pose >= 50 and gate.pose < 100,"Gate swept through player"): return
	scene.player.position = Vector3(-1300,32,-5250)
	await physics_frame
	gate.advance(1.2)
	if not check(gate.pose == 100,"Gate failed to open after obstruction cleared"): return
	if not check(scene.quickload(path).is_empty() and gate.pose == 50,"Disk restore did not restore gate geometry"): return
	# Fresh scene restoration and Jungle→Hive→Jungle transport preserve partial pose.
	var transfer: Dictionary = scene.area_handoff()
	scene.free()
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	if not check(hive.apply_area_handoff(transfer).is_empty(),"Hive rejected gate state"): return
	transfer = hive.area_handoff()
	hive.free()
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_physics_process(false)
	scene.village_dialogue.set_process(false)
	gate = scene.village_gate
	gate.set_physics_process(false)
	if not check(scene.apply_area_handoff(transfer).is_empty() and gate.pose == 50,"Return lost gate checkpoint"): return
	if not check(scene.quickload(path).is_empty() and gate.pose == 50,"Fresh scene failed disk restore"): return
	scene.set_physics_process(false)
	scene.village_dialogue.set_process(false)
	gate.advance(0.6)
	if not check(scene.village_dialogue.active() and scene.village_dialogue.frame == 90,"Fresh save/Hive transport lost partial speech"): return
	scene.village_dialogue.advance(State.SPEECH_DURATION)
	if not check(not scene.village_dialogue.active() and scene.village_dialogue.state().local15 == 1,"Speech completion failed to release walking"): return
	await settle(Vector3(-1300,34,-5250))
	await walk(Vector3.LEFT,105)
	if not check(scene.player.position.x < -1420 and scene.player.is_on_floor() and scene.resets == 0,"Open gate did not allow grounded village entry: %s" % scene.player.position): return
	if not check(not gate.check_contact(),"Gate trigger repeated"): return
	if "--capture-village" in OS.get_cmdline_user_args():
		scene.player.position = Vector3(-1250,34,-5250)
		scene.camera.look_at(Vector3(-1400,75,-5250))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/jungle_village_gate.png")
	if not check(not scene.village_dialogue.begin(),"Completed speech replayed"): return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and not scene.village_dialogue.active(),"Completed speech save failed"): return
	var old_gate: Dictionary = saved.state.duplicate(true)
	old_gate.quests.jungle_village.erase("dialogue")
	if not check(scene.apply_save(old_gate).is_empty() and scene.village_dialogue.state().local15 == 1,"Older opened gate save unexpectedly replayed dialogue"): return
	# Legacy snapshots deliberately start the newly implemented gate closed.
	var legacy: Dictionary = saved.state.duplicate(true)
	legacy.quests.erase("jungle_village")
	if not check(scene.apply_save(legacy).is_empty() and gate.pose == 0,"Legacy gate default incorrect"): return
	scene.free()
	DirAccess.remove_absolute(path)
	print("Jungle village gate PASSED: 820 native predicate cases, closed collision, rescued admission, partial disk save, invalid atomicity, pause, Hive carry, fresh restore and grounded crossing")
	quit()
