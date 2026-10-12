extends SceneTree
## Actual Museum host with physics running: walk onto the walkway (region first contact enables prop153), take the
## Long arm with E, fall with the dropped floors and land in the lower chamber, become tiny through the prop108 timer
## and the shared curse clock, then walk with real W input along the source region-graph portals (tunnel958, duct967
## human-return, side area, lock78 passage) back to region1262 on the main side. Lock78 is preloaded with the Sk key
## (supplied state); the camera/yaw is steered by the test, movement is the host's own.
const State = preload("res://scripts/lol2/museum_long_arm_state.gd")
var museum
var arm
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true
		push_error(message)
		hold(false)
		quit(1)
	return ok
func hold(down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	event.keycode = KEY_W
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func press_e() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	museum._unhandled_input(event)
func foot() -> float: return museum.player.global_position.y - 32.0
func face(target: Vector2) -> void:
	var p: Vector3 = museum.player.global_position
	museum.player.rotation.y = atan2(-(target.x - p.x), -(target.y - p.z))
	museum.camera.rotation = Vector3.ZERO
## Source actor22 (Rat, health40) stands in tunnel region962: fight it with production mouse strikes (tiny melee 1),
## healing through the production spell keys when low, exactly like museum_earned_walk_test.
func fight_rat() -> Dictionary:
	var pop = museum.skeleton_population
	var rat := "22"
	var strikes := 0
	for frame in 60 * 90:
		if int(pop.state.actors[rat].health) <= 0: return {"ok":true,"strikes":strikes,"health":museum.health}
		if museum.health <= 0 or (museum.starting_magic != null and museum.starting_magic.health() <= 0): return {"ok":false,"why":"player died","strikes":strikes}
		if museum.starting_magic != null and museum.starting_magic.health() <= 12 and museum.player_magic_checkpoint.player.mana >= 2 and not museum.starting_magic.protected():
			for code in [KEY_2, KEY_Q, KEY_1]:
				var key := InputEventKey.new(); key.keycode = code; key.pressed = true
				Input.parse_input_event(key); Input.flush_buffered_events()
		var point: Vector3 = pop.bodies[rat].global_position + Vector3(0, 4, 0)
		museum.player.look_at(Vector3(point.x, museum.player.global_position.y, point.z))
		museum.camera.rotation = Vector3.ZERO
		museum.camera.look_at(point)
		if pop.strike_remaining <= 0 and pop.aimed() == rat:
			var strike := InputEventMouseButton.new(); strike.button_index = MOUSE_BUTTON_LEFT; strike.pressed = true
			pop._unhandled_input(strike); strikes += 1
		await physics_frame
	return {"ok":false,"why":"timeout","strikes":strikes,"rat":pop.state.actors[rat].health}

func run() -> void:
	museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum)
	current_scene = museum
	for i in 3: await process_frame
	museum.sword_transfer.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	arm = museum.long_arm
	museum.curse.set_requests_enabled(true)
	# Stand on the walkway (region197 side, floor 40/60) and let physics settle: first contact enables the pedestal.
	var stand := Vector3(-745, 40 + 34, -1150)
	museum.player.global_position = stand
	museum.player.velocity = Vector3.ZERO
	for i in 40: await physics_frame
	if not check(museum.player.is_on_floor() and arm.state.walkway, "Walkway contact: floor %s foot %.1f walkway %s" % [museum.player.is_on_floor(), foot(), arm.state.walkway]): return
	museum.camera.look_at(arm.aim_point())
	await physics_frame
	# Safety prerequisite with the passage still closed: E refused, floors stay up.
	if not check(arm.interaction_hint() == preload("res://scripts/lol2/museum_long_arm.gd").NEED_PASSAGE, "Closed-passage hint: " + arm.interaction_hint()): return
	press_e()
	for i in 20: await physics_frame
	if not check(int(arm.state.stage) == 0 and not State.ITEM in museum.carried_collected and museum.player.is_on_floor() and foot() > 0.0, "Refused take changed state or dropped floors"): return
	# Supplied: Sk key placed in control78 (passage open), no key carried.
	if not check(museum.key_locks.restore_checkpoint({"version":1,"loaded":[78],"panel_state":0}).is_empty(), "Lock78 state"): return
	museum.camera.look_at(arm.aim_point())
	await physics_frame
	if not check(arm.interaction_hint() == "E — Take Long arm", "Pedestal hint: " + arm.interaction_hint()): return
	DirAccess.make_dir_recursive_absolute("user://tests")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/long_arm_pedestal.png")
	press_e()
	if not check(int(arm.state.stage) == 1 and State.ITEM in museum.carried_collected, "Take"): return
	museum.hand_item = ""
	# Fall and land.
	var landed := false
	for i in 240:
		await physics_frame
		if museum.player.is_on_floor() and foot() < -150.0: landed = true; break
	if not check(landed and foot() > -225.0, "Fall/landing: foot %.1f on_floor %s" % [foot(), museum.player.is_on_floor()]): return
	var landing := foot()
	# Timer (2.5 s) + curse warning (3.57 s) -> tiny.
	var tiny := false
	for i in 600:
		await physics_frame
		if int(museum.player_form) == 2: tiny = true; break
	if not check(tiny and not arm.state.pending, "No tiny form: form %d curse %s arm %s" % [museum.player_form, museum.curse.state, arm.state]): return
	# Walk the portals with real W input.
	var portals: Array = arm.source.escape.portals
	var index := 0
	var best := INF
	var stalled := 0.0
	var human_again := false
	var fight := {}
	hold(true)
	for frame in 60 * 150:
		if index == 12 and fight.is_empty():
			hold(false)
			fight = await fight_rat()
			if not check(bool(fight.ok), "Rat fight failed: %s form %d curse %s" % [fight, museum.player_form, museum.curse.state]): return
			hold(true)
		var target: Vector2 = Vector2(float(portals[index].xz[0]), float(portals[index].xz[1]))
		face(target)
		await physics_frame
		var p: Vector3 = museum.player.global_position
		var d := Vector2(p.x, p.z).distance_to(target)
		if int(museum.player_form) == 0 and index > 14: human_again = true
		if d < 6.0:
			index += 1; best = INF; stalled = 0.0
			if index == portals.size(): break
			continue
		if d < best - 0.5: best = d; stalled = 0.0
		else: stalled += 1.0 / 60.0
		if stalled > 6.0:
			check(false, "Stalled before portal %d (region %s) at %s, d=%.1f form %d curse %s" % [index, portals[index].region, p, d, museum.player_form, museum.curse.state])
			return
	hold(false)
	if not check(index == portals.size(), "Escape incomplete at portal %d" % index): return
	var end: Vector3 = museum.player.global_position
	if not check(absf(foot()) < 4.0, "Not back at main-side floor: %s" % [end]): return
	if not check(human_again and int(museum.player_form) == 0 and museum.health > 0 and museum.resets == 0, "Escape must finish alive, human and without recovery reset"): return
	var path := "user://tests/long_arm_escaped.json"
	var saved_position: Vector3 = museum.player.global_position
	var saved_health: int = museum.health
	if not check(museum.quicksave(path).is_empty() and museum.quickload(path).is_empty(), "Actual escaped save/reload"): return
	if not check(int(museum.player_form) == 0 and museum.health == saved_health and museum.player.global_position.distance_to(saved_position) < 0.01 and museum.carried_collected.count(State.ITEM) == 1 and int(arm.state.stage) > 0 and not arm.pedestal.visible, "Escaped reload lost player, reward or trap state"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/long_arm_escaped.png")
	print("PASS museum_long_arm_escape: walkway contact enabled prop153, closed-passage E refused (floors stayed), passage78 opened, E take, fell and landed at foot %.1f, tiny via timer+curse, walked %d portals with W through tunnel958 (rat22 defeated with %d production tiny strikes), duct967/lock78 passage to region1262 (form now %d, human return seen %s)." % [landing, portals.size(), int(fight.get("strikes",0)), museum.player_form, human_again])
	quit()
