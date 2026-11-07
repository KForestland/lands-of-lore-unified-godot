extends SceneTree
const State = preload("res://scripts/lol2/jungle_followup_state.gd")
var scene
var gate
var actor
var path := "user://tests/followup_%d.json" % Time.get_ticks_usec()
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if ok: return true
	push_error(message)
	DirAccess.remove_absolute(path)
	quit(1)
	return false
func settle(point: Vector3) -> void:
	scene.player.position = point
	scene.player.velocity = Vector3.ZERO
	for i in range(40):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,1.0/60)
func bind_nodes() -> void:
	gate = scene.followup_gate
	actor = scene.followup_dialogue
	scene.set_physics_process(false)
	scene.set_process_unhandled_input(false)
	gate.set_physics_process(false)
	actor.set_process(false)
func run() -> void:
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	bind_nodes()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await settle(Vector3(-1700,34,-4430))
	gate.was_inside = false
	if not check(not gate.check_contact() and not actor.active(),"Unarmed follow-up played"): return
	await settle(Vector3(-1660,34,-4300))
	if not check(gate.in_arming_region() and scene.player.is_on_floor(),"Arming approach not grounded"): return
	scene.village_gate.state().shared29 = 1
	gate.was_arming = false
	gate.check_contact()
	if not check(gate.state().local18 == 0,"Hostile state armed follow-up"): return
	scene.village_gate.state().shared29 = 0
	gate.was_arming = false
	gate.check_contact()
	if not check(gate.state().local18 == 1 and actor.visible,"Source region3262 did not arm villager"): return
	# Walk between the two source trigger regions, without teleporting between them.
	for i in range(150):
		await physics_frame
		scene.move_grounded(Vector3.FORWARD,1.0/60)
		gate.check_contact()
		if actor.active(): break
	if not check(actor.active() and actor.audio.playing and gate.state().local18 == 2,"Source region3255 did not start speech"): return
	var stopped: Vector3 = scene.player.position
	for i in range(15):
		await physics_frame
		scene.move_grounded(Vector3.LEFT,1.0/60)
	if not check(stopped.distance_to(scene.player.position)<0.1,"Follow-up failed to hold walking"): return
	actor.advance(5)
	gate.advance(0.6)
	if not check(actor.frame == 75 and gate.pose == 50,"Partial speech/gate pose wrong"): return
	if not check(scene.quicksave(path).is_empty(),"Follow-up disk save failed"): return
	var saved: Dictionary = scene.Save.read_save(path).state
	var disk := FileAccess.get_file_as_bytes(path)
	for bad in [NAN,INF,-1,34,true,"bad"]:
		var invalid := saved.duplicate(true)
		invalid.quests.jungle_village.followup.speech = bad
		if not check(not scene.apply_save(invalid).is_empty() and actor.frame == 75,"Invalid follow-up changed scene"): return
		if not check(not scene.Save.write_save(path,invalid).is_empty() and FileAccess.get_file_as_bytes(path)==disk,"Invalid follow-up changed save"): return
	paused = true
	actor.advance(10)
	gate.advance(10)
	paused = false
	actor.advance(-1)
	if not check(actor.frame == 75 and gate.pose == 50,"Pause/negative clock changed follow-up"): return
	var transfer: Dictionary = scene.area_handoff()
	scene.free()
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	if not check(hive.apply_area_handoff(transfer).is_empty(),"Hive rejected follow-up"): return
	transfer = hive.area_handoff()
	hive.free()
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	bind_nodes()
	if not check(scene.apply_area_handoff(transfer).is_empty() and gate.pose == 50 and actor.frame == 75,"Hive lost partial follow-up"): return
	if not check(scene.quickload(path).is_empty() and actor.active(),"Fresh disk restore failed"): return
	gate.advance(0.6)
	if not check(gate.pose == 100,"Follow-up gate failed to open"): return
	actor.advance(State.DURATION)
	if not check(not actor.active() and not actor.visible,"Speech completion did not hide/release"): return
	var safe: Vector3 = scene.player.position
	var center := Vector3.ZERO
	var count := 0
	for face in gate.data.leaves[0].frames[50]:
		for v in face.vertices:
			center += Vector3(v[0],v[1],v[2])
			count += 1
	center /= count
	scene.player.position = Vector3(center.x,34,center.z)
	scene.player.force_update_transform()
	await physics_frame
	await physics_frame
	gate.advance(1.2)
	if not check(gate.pose > 0,"Closing gate swept through player"): return
	scene.player.position = safe
	await physics_frame
	gate.state().elapsed = 1.2
	gate.restore()
	gate.advance(0.6)
	if not check(gate.pose == 50,"Follow-up gate did not close halfway"): return
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and gate.pose == 50 and not actor.active(),"Closing gate checkpoint failed"): return
	gate.advance(0.6)
	if not check(gate.pose == 0,"Follow-up gate did not close"): return
	var before: Vector3 = scene.player.position
	for i in range(15):
		await physics_frame
		scene.move_grounded(Vector3.BACK,1.0/60)
	if not check(scene.player.position.distance_to(before)>5,"Speech did not release walking"): return
	for branch in [40,50]:
		var alternate := saved.duplicate(true)
		alternate.quests.jungle_village.followup = State.initial()
		alternate.quests.jungle_village.followup.local18 = 1
		alternate.quests.jungle_village.followup.shared18 = 1 if branch == 40 else 0
		alternate.quests.jungle_village.dialogue.local46 = 1 if branch == 50 else 0
		if not check(scene.apply_save(alternate).is_empty(),"Alternate follow-up save rejected"): return
		await settle(Vector3(-1700,34,-4430))
		gate.was_inside = false
		gate.check_contact()
		if not check(gate.state().local18 == branch and not actor.active() and not actor.visible,"Alternate follow-up branch played normal speech"): return
	var legacy := saved.duplicate(true)
	legacy.quests.jungle_village.erase("followup")
	if not check(scene.apply_save(legacy).is_empty() and gate.state().local18 == 0 and gate.pose == 0,"Legacy follow-up default incorrect"): return
	if "--capture-followup" in OS.get_cmdline_user_args():
		scene.apply_save(saved)
		scene.player.position = Vector3(-1710,34,-4430)
		scene.camera.look_at(Vector3(-1883,65,-4501))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/jungle_followup.png")
	scene.free()
	DirAccess.remove_absolute(path)
	print("Village follow-up PASSED: two-region admission, original speech, gate open/close, pause, movement lock/release, disk/Hive transport and invalid-save atomicity")
	quit()
