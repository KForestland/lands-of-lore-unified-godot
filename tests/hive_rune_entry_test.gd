extends SceneTree
func _initialize(): run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run():
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(false)
	root.grab_focus()
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var entry = scene.runes
	# Supplied nearby aim fixture, not a route from the earned wax checkpoint.
	scene.player.position = Vector3(-3156,-1620,-6138)
	var point := Vector3(-3156,-1657,-6178)
	var direction: Vector3 = point-scene.camera.global_position
	scene.player.rotation.y = atan2(-direction.x,-direction.z)
	scene.camera.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
	await physics_frame
	if not check(entry.target(),"Original control mesh not reachable by fixture ray"): return
	scene.interface_hud._process(0)
	if not check(scene.interface_hud.hint.text == "E — Examine rune room","Room interaction hint missing"): return
	scene.interface_hud.set_cursor(true)
	if not check(not entry.interact(),"Interface must block entry"): return
	scene.interface_hud.set_cursor(false)
	key(KEY_E)
	await process_frame
	if not check(entry.active() and not scene.is_physics_processing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"E must open room and lock world input"): return
	if not check(not scene.open_inventory(),"Room must prevent world inventory opening"): return
	key(KEY_SPACE)
	if not check(not scene.jump_requested,"Room queued a jump"): return
	var magic_model = preload("res://scripts/lol2/hive_magic_reward.gd")
	var reward := magic_model.award_checkpoint({"version":1,"player":{"experience":249,"level":1,"maximum":20,"mana":7}},1,[159])
	if not check(not reward.has("error") and reward.state.maximum == 35 and reward.state.mana == 22,"Magic level award failed"): return
	scene.player_magic_checkpoint = reward.checkpoint
	var before: Dictionary = scene.area_handoff()
	var path := "user://tests/rune_entry_%d.json" % Time.get_ticks_usec()
	var save_error: String = scene.quicksave(path)
	if not check(save_error.is_empty(),"Room save failed: "+save_error): return
	var height: float = scene.player.position.y
	key(KEY_ESCAPE)
	if not check(not entry.active() and entry.checkpoint.flag286,"Escape did not set source exit flag"): return
	if not check(Vector2(scene.player.position.x,scene.player.position.z) == Vector2(-3116,-6284) and scene.player.position.y == height,"Exit pose or preserved height differs"): return
	if not check(is_equal_approx(scene.player.rotation.y,-PI/4),"Exit bearing differs"): return
	if not check(scene.quickload(path).is_empty() and entry.active(),"Saved room did not resume"): return
	if not check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not scene.is_physics_processing(),"Resume lost room input lock"): return
	if not check(scene.player_magic_checkpoint == reward.checkpoint,"Room save lost magic progression"): return
	var invalid_magic: Dictionary = before.duplicate(true)
	invalid_magic.quests.player_magic_reward_state.player.level = 31
	if not check(not scene.apply_area_handoff(invalid_magic).is_empty() and scene.player_magic_checkpoint == reward.checkpoint,"Invalid magic checkpoint was not rejected atomically"): return
	var invalid: Dictionary = before.duplicate(true)
	invalid.quests.hive_rune_entry.marker642_enabled = false
	if not check(not scene.apply_area_handoff(invalid).is_empty() and entry.active(),"Malformed state changed live room"): return
	entry.leave()
	var after: Dictionary = scene.area_handoff()
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	if not check(jungle.apply_area_handoff(after).is_empty(),"Jungle rejected rune entry state"): return
	if not check(jungle.area_handoff().quests.hive_rune_entry == after.quests.hive_rune_entry,"Jungle lost rune entry state"): return
	if not check(jungle.area_handoff().quests.player_magic_reward_state == reward.checkpoint,"Jungle lost magic progression"): return
	jungle.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: source rune control E entry, input locks, source return pose, room saves and Jungle carry")
	quit()
