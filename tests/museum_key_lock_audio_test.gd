extends SceneTree
## Sk-key lock sounds and narration (owner r10 2026-10-23: "the key is in but no sound, no library telling you of the
## worm"; "can't take back the key"). Real E presses: the key from control87, then into lock142: skelkey1 (676) and
## the lock's op24 narration chain 28 → 29 in order (each next clip when one ends). With SS1 in the hand, E puts SS1
## away and takes the key back: skelkey2 (677), narration stopped. A sconce never burns through that retry.
const State = preload("res://scripts/lol2/museum_key_locks_state.gd")
var museum
var locks
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true
		push_error(message); print("FAIL museum_key_lock_audio: ", message)
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
	museum.set_physics_process(false)
	museum.sword_transfer.set_process(false)
	museum.gallery.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	locks = museum.key_locks
	if not check(is_instance_valid(locks) and not locks.audio.is_empty(), "Lock audio not prepared"): return
	if not check(locks.audio.locks["88"].chain == [17.0, 18.0, 19.0, 20.0], "Worm lock chain differs"): return
	await view(locks.aim_point(87)); press()
	if not check(museum.hand_item == State.KEY, "control87 take"): return
	if not check(locks.played == [677], "Taking from control87 did not play skelkey2: %s" % [locks.played]): return
	locks.played.clear()
	if not check(await view(locks.aim_point(142)), "No vantage for lock142"): return
	press()
	if not check(State.is_loaded(locks.state, 142) and locks.sound.playing and locks.played == [676], "Insert did not play skelkey1: %s" % [locks.played]): return
	for i in 1400:
		await process_frame
		if locks.played.size() >= 3 and not locks.narration.playing and locks.narrating.is_empty(): break
	if not check(locks.played == [676, 28, 29] and locks.narrating.is_empty(), "Narration chain differs: %s" % [locks.played]): return
	# Again, then take it back mid-narration with SS1 in the hand.
	museum.hand_item = ""; press()
	museum.hand_item = State.KEY; press()
	for i in 200:
		await process_frame
		if locks.narration.playing: break
	if not check(locks.narration.playing, "Second insert narration did not start"): return
	locks.played.clear()
	if not State.SS1 in museum.carried_collected: museum.carried_collected.append(State.SS1)
	museum.hand_item = State.SS1; press()
	if not check(not State.is_loaded(locks.state, 142) and museum.hand_item == State.KEY and State.SS1 in museum.carried_collected, "E with SS1 in hand did not take the key back"): return
	if not check(locks.played == [677] and not locks.narration.playing and locks.narrating.is_empty(), "Take did not stop the narration: %s" % [locks.played]): return
	print("PASS museum_key_lock_audio: skelkey1 then narration 28, 29 in order at lock142; with SS1 in hand E takes the key back with skelkey2 and the narration stops")
	quit(0)
