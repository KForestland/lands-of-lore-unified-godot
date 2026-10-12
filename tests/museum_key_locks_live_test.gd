extends SceneTree
## Actual Museum host: E through museum._unhandled_input at all 17 Sk-key locks, the single key from control87,
## control140/gallery lever regression, control113 sconces, control114 panel/SS1, quicksave/quickload without duplication.
## Vantage points are searched around each source lock position (supplied camera placement, real reach/aim/occlusion).
const State = preload("res://scripts/lol2/museum_key_locks_state.gd")
var museum
var locks
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true
		push_error(message)
		quit(1)
	return ok
func press() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	museum._unhandled_input(event)
func view(target: Vector3) -> bool:
	for distance in [45.0, 70.0, 30.0, 88.0]:
		for step in 16:
			var d := Vector3(cos(step * TAU / 16.0), 0, sin(step * TAU / 16.0))
			for lift in [0.0, -12.0, 12.0]:
				var eye: Vector3 = target + d * distance + Vector3(0, lift, 0)
				museum.player.position = eye - Vector3(0, museum.camera.position.y, 0)
				museum.camera.rotation = Vector3.ZERO
				museum.player.rotation = Vector3.ZERO
				museum.camera.look_at(target)
				await physics_frame
				if museum.can_reach_item(target): return true
	return false
## Ray through the lock78 passage (region1262 -> 1237/1477 -> 1459) at height 40.
func passage_blocked() -> bool:
	await physics_frame
	var q := PhysicsRayQueryParameters3D.create(Vector3(-2000, 40, -1085), Vector3(-1950, 40, -1085))
	q.exclude = [museum.player.get_rid()]
	return not museum.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
func save_cycle(tag: String) -> bool:
	var path := "user://tests/museum_key_locks_%s_%d.json" % [tag, OS.get_process_id()]
	var error: String = museum.quicksave(path)
	if not check(error.is_empty(), "Save %s: %s" % [tag, error]): return false
	var before: Dictionary = locks.checkpoint()
	var carried: Array = museum.carried_collected.duplicate()
	for i in 2:
		error = museum.quickload(path)
		if not check(error.is_empty(), "Load %s: %s" % [tag, error]): return false
	return check(locks.checkpoint() == before and museum.carried_collected == carried and museum.carried_collected.count(State.KEY) <= 1, "Save cycle changed state " + tag)
func run() -> void:
	museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum)
	current_scene = museum
	await process_frame
	museum.set_physics_process(false)
	museum.sword_transfer.set_process(false)
	museum.gallery.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	locks = museum.key_locks
	if not check(is_instance_valid(locks) and locks.checkpoint() == State.initial(), "Key locks missing or not initial"): return
	if not check(await passage_blocked(), "Passage open before lock78"): return
	for id in State.LOCKS:
		if not check(locks.key_markers[id].visible == (id == 87), "Initial marker %d" % id): return
	var unreachable: Array = []
	for id in State.LOCKS:
		if not await view(locks.aim_point(id)): unreachable.append(id)
	if not check(unreachable.is_empty(), "No vantage for locks %s" % [unreachable]): return
	# The only key: control87.
	await view(locks.aim_point(87))
	if not check(locks.interaction_hint() == "E — Take Sk key", "control87 hint: " + locks.interaction_hint()): return
	press()
	if not check(museum.carried_collected.count(State.KEY) == 1 and museum.hand_item == State.KEY and not locks.key_markers[87].visible, "control87 take"): return
	if not save_cycle("carried"): return
	# Gallery regression first: painting + lever53 route still opens grate51 with no key involved.
	museum.hand_item = ""
	museum.player.position = Vector3(1900, 32, -1454)
	museum.camera.rotation = Vector3.ZERO
	museum.camera.look_at(museum.gallery.painting.global_position)
	await physics_frame
	press()
	museum.camera.look_at(museum.gallery.lever.global_position)
	await physics_frame
	press()
	if not check(museum.gallery.painting_moved and museum.gallery.lever_pulled and museum.gallery.gate_open, "Lever53 route"): return
	museum.hand_item = State.KEY
	var lines: Array = []
	for id in State.LOCKS:
		if not await view(locks.aim_point(id)): return
		if not check(locks.interaction_hint() == "E — Place Sk key in the lock", "Insert hint %d: %s" % [id, locks.interaction_hint()]): return
		press()
		if not check(State.is_loaded(locks.state, id) and not State.KEY in museum.carried_collected and museum.hand_item == "" and locks.key_markers[id].visible, "Insert %d" % id): return
		var effect := ""
		match id:
			78:
				if not check(not await passage_blocked() and locks.passage.open.visible, "control78 passage open"): return
				if not check(locks.passage.open.get_children().all(func(c): return not c is MeshInstance3D or c.material_override != null), "Passage materials"): return
				if not save_cycle("passage") or not await view(locks.aim_point(id)): return
				if not check(not await passage_blocked(), "Passage after load"): return
				effect = " passage regions1237/1477 open (ray clear, saved)"
			140:
				if not check(museum.gallery.gate_open and museum.gallery.lever_pulled, "control140 insert gallery"): return
				effect = " grate open"
			113:
				if not check(locks.flames.all(func(f): return f.visible), "control113 sconces"): return
				effect = " %d sconces lit" % locks.flames.size()
			114:
				if not check(locks.panel.visible and locks.panel_item.visible, "control114 panel"): return
				if not await view(locks.panel.global_position): return
				if not check(locks.interaction_hint() == "E — Take SS1", "SS1 hint " + locks.interaction_hint()): return
				press()
				if not check(museum.carried_collected.count(State.SS1) == 1 and museum.hand_item == State.SS1 and not locks.panel_item.visible, "Take SS1"): return
				if not save_cycle("ss1"): return
				# quickload restores yaw on the player body and pitch on the camera: aim again.
				if not await view(locks.panel.global_position): return
				press()
				if not check(State.SS1 not in museum.carried_collected and locks.panel_item.visible and int(locks.state.panel_state) == 0, "Return SS1"): return
				if not await view(locks.aim_point(id)): return
				effect = " panel lowered, SS1 taken/saved/returned"
		if id == 145:
			if not save_cycle("loaded145") or not await view(locks.aim_point(id)): return
		if not check(locks.interaction_hint() == "E — Take Sk key", "Take hint %d" % id): return
		press()
		if not check(not State.is_loaded(locks.state, id) and museum.carried_collected.count(State.KEY) == 1 and museum.hand_item == State.KEY, "Take %d" % id): return
		match id:
			78:
				if not check(await passage_blocked() and not locks.passage.open.visible, "control78 passage closed"): return
				effect += ", closed on take"
			140:
				if not check(not museum.gallery.gate_open and not museum.gallery.lever_pulled, "control140 take gallery"): return
				# Lever53 can be pulled again after the lock's take group reset it.
				museum.hand_item = ""
				museum.player.position = Vector3(1900, 32, -1454)
				museum.camera.rotation = Vector3.ZERO
				museum.camera.look_at(museum.gallery.lever.global_position)
				await physics_frame
				press()
				if not check(museum.gallery.gate_open and museum.gallery.lever_pulled, "Lever53 after lock140"): return
				if not save_cycle("gallery"): return
				museum.hand_item = State.KEY
				effect += ", closed on take, lever re-pulled"
			113:
				if not check(not locks.flames.any(func(f): return f.visible), "control113 take"): return
			114:
				if not check(not locks.panel.visible, "control114 take"): return
		lines.append("%d%s" % [id, effect])
	if not save_cycle("end"): return
	print("PASS museum_key_locks_live: actual host E at all 17 locks (", ", ".join(lines), "); single control87 key, save/load x2 without duplication, lever53 gallery route before/after lock140.")
	quit()
