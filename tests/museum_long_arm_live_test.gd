extends SceneTree
## Actual Museum host: prop153 Long arm pickup by E (one-time grant into the hand), walkway floors drop (collision ray),
## save/load mid-timer without duplication, prop108 timer -> form2 request only when curse requests are admitted,
## Long arm equips as a weapon, museum_save rejects inconsistent pickup state. Supplied camera vantage.
const State = preload("res://scripts/lol2/museum_long_arm_state.gd")
var museum
var arm
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
## Height of the first floor below a walkway point beside the pedestal.
func floor_height() -> float:
	await physics_frame
	var q := PhysicsRayQueryParameters3D.create(Vector3(-745, 100, -1150), Vector3(-745, -260, -1150))
	q.exclude = [museum.player.get_rid()]
	var hit: Dictionary = museum.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position.y if not hit.is_empty() else -999.0
func cycle(tag: String) -> bool:
	var path := "user://tests/museum_long_arm_%s_%d.json" % [tag, OS.get_process_id()]
	var error: String = museum.quicksave(path)
	if not check(error.is_empty(), "Save %s: %s" % [tag, error]): return false
	var before: Dictionary = arm.checkpoint()
	error = museum.quickload(path)
	return check(error.is_empty() and arm.checkpoint() == before and museum.carried_collected.count(State.ITEM) == int(before.stage > 0), "Reload %s: %s" % [tag, error])
func run() -> void:
	museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum)
	current_scene = museum
	await process_frame
	await process_frame
	museum.set_physics_process(false)
	museum.sword_transfer.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	arm = museum.long_arm
	# Logic test: the owner's own region polling is exercised with physics in museum_long_arm_escape_test.
	arm.set_physics_process(false)
	if not check(is_instance_valid(arm) and arm.checkpoint() == State.initial() and arm.pedestal.visible, "Long arm owner missing or not initial"): return
	var raised: float = await floor_height()
	if not check(absf(raised - 40.0) < 1.0 or absf(raised - 60.0) < 1.0, "Walkway floor before take: %f" % raised): return
	if not check(await view(arm.aim_point()), "No pedestal vantage"): return
	# A busy hand cannot take it (source record is the empty-hand mode0).
	museum.carried_collected.append("museum:item8:Champion_Stone")
	museum.hand_item = "museum:item8:Champion_Stone"
	press()
	if not check(arm.interaction_hint() == "" and int(arm.state.stage) == 0, "Busy hand admitted"): return
	museum.hand_item = ""
	if not check(arm.interaction_hint() == "", "Pedestal enabled before walkway contact"): return
	arm.state.walkway = true # Region first contact is exercised by museum_long_arm_escape_test with physics.
	# Safety prerequisite: passage78 closed (Sk key still in control87) -> refused, nothing changes, save/load keeps it.
	var Arm = preload("res://scripts/lol2/museum_long_arm.gd")
	for branch in ["passage","curse"]:
		if branch == "passage":
			if not check(not State.ITEM in museum.carried_collected and museum.key_locks.checkpoint().loaded == [87], "Unexpected lock state"): return
		else:
			if not check(museum.key_locks.restore_checkpoint({"version":1,"loaded":[78],"panel_state":0}).is_empty() and museum.key_locks.passage.open.visible, "Lock78 open"): return
			museum.curse.set_requests_enabled(false)
		var expect: String = Arm.NEED_PASSAGE if branch == "passage" else Arm.NEED_CURSE
		var before_state: Dictionary = arm.checkpoint()
		var before_items: Array = museum.carried_collected.duplicate()
		if not check(arm.interaction_hint() == expect, branch + " hint: " + arm.interaction_hint()): return
		press()
		if not check(arm.checkpoint() == before_state and museum.carried_collected == before_items and museum.hand_item == "" and arm.pedestal.visible and absf(await floor_height() - raised) < 1.0, branch + " refusal changed state"): return
		if not cycle("refused_" + branch): return
		await view(arm.aim_point())
		arm.state.walkway = true
		if not check(arm.interaction_hint() == expect, branch + " refusal lost on reload"): return
	museum.curse.set_requests_enabled(true)
	if not check(arm.interaction_hint() == "E — Take Long arm", "Hint after opening passage78: " + arm.interaction_hint()): return
	press()
	if not check(int(arm.state.stage) == 1 and museum.carried_collected.count(State.ITEM) == 1 and museum.hand_item == State.ITEM and not arm.pedestal.visible, "Take"): return
	var dropped: float = await floor_height()
	if not check(absf(dropped + 210.0) < 1.0 or absf(dropped + 190.0) < 1.0, "Walkway floor after take: %f" % dropped): return
	museum.hand_item = ""
	if not check(not arm.use() and museum.carried_collected.count(State.ITEM) == 1, "Second take"): return
	arm.state.elapsed = 1.0
	if not cycle("timer"): return
	if not check(absf(float(arm.state.elapsed) - 1.0) < 0.001 and await floor_height() < -180.0, "Mid-timer reload"): return
	# Owed form2 request (forced-form adapter): human, beast, already tiny, disabled, active transitions.
	var Curse = preload("res://scripts/lol2/player_curse.gd")
	var cases := []
	for case in ["human","beast","tiny","disabled","warning","returning"]:
		museum.curse.restore(Curse.initial())
		museum.curse.set_requests_enabled(case != "disabled")
		museum.player_form = {"beast":1,"tiny":2,"returning":1}.get(case,0)
		if case == "warning": museum.curse.state.merge({"phase":1,"previous":0,"target":1,"remaining":1.0,"duration":70.0},true)
		if case == "returning": museum.curse.state.merge({"phase":3,"previous":1,"target":0,"remaining":0.0,"duration":0.0},true)
		arm.state.merge({"stage":1,"elapsed":0.0,"pending":false},true)
		arm.last_form_request = false
		if not check(State.advance(arm.state, State.TIMER) and arm.state.pending, "Timer did not owe a request: "+case): return
		var applied: bool = arm.apply_owed_form()
		var phase := int(museum.curse.state.phase)
		match case:
			"human", "beast":
				if not check(applied and not arm.state.pending and phase == 1 and int(museum.curse.state.target) == 2 and int(museum.curse.state.previous) == int(museum.player_form) and Curse.valid(museum.curse.state, museum.player_form), case+" not forced: %s" % [museum.curse.state]): return
			"tiny":
				if not check(applied and not arm.state.pending and phase == 0, "tiny changed: %s" % [museum.curse.state]): return
			_:
				if not check(not applied and arm.state.pending, case+" applied while blocked"): return
				if not cycle("owed_"+case): return
				if not check(arm.state.pending, case+" lost across save/load"): return
				# Unblock: admission back on / transition finished.
				museum.curse.set_requests_enabled(true)
				if case != "disabled":
					museum.curse.state.merge({"phase":0,"target":0,"remaining":0.0,"duration":0.0},true)
					museum.player_form = 0
				if not check(arm.apply_owed_form() and not arm.state.pending and int(museum.curse.state.target) == 2, case+" not applied after unblock"): return
		cases.append(case)
	# Chamber re-arm restarts the timer for a non-tiny player once nothing is owed.
	arm.state.merge({"stage":2,"elapsed":0.0,"pending":false},true)
	if not check(State.rearm(arm.state, 0) and int(arm.state.stage) == 1 and not State.rearm(arm.state, 0), "Re-arm"): return
	arm.state.merge({"stage":2,"elapsed":0.0,"pending":false},true)
	if not check(not State.rearm(arm.state, 2), "Re-arm while tiny"): return
	museum.curse.restore(Curse.initial())
	museum.player_form = 0
	if not cycle("expired"): return
	if not check(museum.set_equipped_item(State.ITEM) and museum.equipped_item == State.ITEM, "Long arm does not equip"): return
	if not cycle("equipped"): return
	var saved: Dictionary = museum.capture_exhibit_retry()
	# Save validation: carrying the axe needs a taken stage, and a taken stage needs the axe.
	var Save = preload("res://scripts/lol2/museum_save.gd")
	saved.checkpoint.erase("museum_long_arm")
	if not check(not Save.validate(saved).is_empty(), "Legacy save with Long arm accepted"): return
	saved.checkpoint.museum_long_arm = {"version":1,"stage":2,"elapsed":0,"walkway":true,"pending":false}
	if not check(Save.validate(saved).is_empty(), "Valid Long arm save rejected: " + Save.validate(saved)): return
	saved.checkpoint.collected.erase(State.ITEM)
	if saved.checkpoint.equipped_item == State.ITEM: saved.checkpoint.equipped_item = ""
	if not check(not Save.validate(saved).is_empty(), "Taken stage without item accepted"): return
	print("PASS museum_long_arm_live: safety prerequisite refuses (passage78 closed, curse stilled) with hint and unchanged item/floors/state through save/load; then E takes Long arm once into the hand (busy hand refused), walkway floor %d -> %d, mid-timer save/load, owed form2 request forced for human/beast, kept through disabled/warning/returning (and save/load) until applied, tiny unchanged, chamber re-arm, equips as weapon, save validation." % [raised, dropped])
	quit()
