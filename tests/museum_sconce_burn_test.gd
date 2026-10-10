extends SceneTree
## Actual Museum host: lit sconces (Sk key in control113) burn an empty hand through E (source op19, modern amount 5);
## unlit sconces, a busy hand and control134 (no empty-hand record) do nothing. Supplied camera vantages.
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
	locks = museum.key_locks
	var magic = museum.starting_magic
	if not check(magic != null, "No starting magic/health owner"): return
	# Unlit: no burn offered.
	if not check(await view(locks.sconce_point(117)) and locks.interaction_hint() == "", "Unlit sconce offers: " + locks.interaction_hint()): return
	# Earn the key and light the sconces through the real locks.
	if not check(await view(locks.aim_point(87)), "No vantage control87"): return
	press()
	if not check(await view(locks.aim_point(113)), "No vantage control113"): return
	press()
	if not check(State.sconces_lit(locks.state) and museum.hand_item == "", "Sconces not lit"): return
	magic.set_health(20)
	var burned := 0
	for id in locks.source.sconces:
		if not await view(locks.sconce_point(id)): continue
		var before: int = magic.health()
		var hint: String = locks.interaction_hint()
		press()
		if int(id) == 134:
			if not check(hint == "" and magic.health() == before, "control134 burned"): return
			continue
		if not check(hint == "E — Touch the burning sconce" and magic.health() == maxi(0, before - 5), "Sconce %s burn %d -> %d" % [id, before, magic.health()]): return
		burned += 1
		if magic.health() == 0: magic.set_health(20)
	if not check(burned == 22, "Too few reachable sconces: %d" % burned): return
	# The real shared health owner persists a burn and respects pause/death admission.
	if not check(await view(locks.sconce_point(117)), "Sconce persistence vantage"): return
	magic.set_health(13)
	paused = true; press(); paused = false
	if not check(magic.health() == 13, "Pause admitted burn"): return
	press()
	var path := "user://tests/sconce_burn_lead.json"
	var error: String = museum.quicksave(path)
	if not check(magic.health() == 8 and error.is_empty(), "Burn save: " + error): return
	press()
	if not check(magic.health() == 3, "Second burn"): return
	error = museum.quickload(path)
	if not check(error.is_empty() and magic.health() == 8 and State.sconces_lit(locks.state), "Burn reload: " + error): return
	if not check(await view(locks.sconce_point(117)), "Re-aim after reload"): return
	magic.set_health(3); press()
	if not check(magic.health() == 0 and locks.interaction_hint() == "", "Dead player still admitted"): return
	press()
	if not check(magic.health() == 0, "Dead player burned below zero"): return
	magic.set_health(20)
	# A busy hand does nothing (the 57b-Fire brnt recharge is unresolved: no known pre-exit producer, none in the current port).
	museum.carried_collected.append("museum:item8:Champion_Stone")
	museum.hand_item = "museum:item8:Champion_Stone"
	await view(locks.sconce_point(117))
	var before := int(magic.health())
	press()
	if not check(magic.health() == before and locks.interaction_hint() == "", "Busy hand burned"): return
	print("PASS museum_sconce_burn: lit sconces burn an empty hand for 5 via host E (%d sconces), control134/unlit/busy hand do nothing; health floor 0." % burned)
	quit()
