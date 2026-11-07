extends SceneTree
## Owner r3 playtest 2026-10-20 report11-50-45: Fine Longsword equipped, hourglass struck, wall cracked (stage1),
## camera (1384.46,42.05,-496.56) yaw-1.7574 pitch-0.0540 looking straight at the wall; no hint, clicks did nothing.
## The original takes melee on control97 wherever the wall is aimed (longplay30:14 swings at the wall face).
func _initialize(): run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL museum_escape_wall_aim: ", message); quit(1); return false
func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func pose(scene, position: Vector3, yaw: float, pitch: float) -> void:
	scene.player.position = position
	scene.player.rotation = Vector3(0,yaw,0)
	scene.camera.rotation = Vector3(pitch,0,0)
	await physics_frame
	await physics_frame
func run():
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.hourglass.set_process(false)
	var wall = scene.escape_wall
	wall.set_process(false)
	scene.carried_collected.append(scene.SWORD_ITEM_ID)
	scene.sword_transfer.collect()
	if not scene.set_equipped_item(scene.SWORD_ITEM_ID): return fail("Fine Longsword not equippable")
	if not scene.hourglass.receive_hit(): return fail("Hourglass refused its hit")
	wall.set_stage(1)
	# Owner pose: body foot 10 below the camera.
	await pose(scene, Vector3(1384.46,32.05,-496.56), -1.75738835334778, -0.054004579782486)
	if not scene.can_strike_escape_wall(): return fail("Owner pose looking straight at the cracked wall cannot strike it")
	scene._physics_process(0.0)
	if scene.interaction_label.text != "Left click — Break damaged wall" or not scene.interaction_label.visible:
		return fail("No strike hint at the owner pose: '%s'" % scene.interaction_label.text)
	# Close range, level gaze (the old centre-point cone needed ~55 deg upward pitch here).
	await pose(scene, Vector3(1414,32.05,-492), -PI/2, 0.0)
	if not scene.can_strike_escape_wall(): return fail("Level gaze 15 units from the wall cannot strike")
	# Refusals: looking along the corridor wall, aiming over the top, out of reach, unarmed.
	await pose(scene, Vector3(1414,32.05,-492), 0.0, 0.0)
	if scene.can_strike_escape_wall(): return fail("Strike admitted while looking away")
	await pose(scene, Vector3(1414,32.05,-492), -PI/2, 1.45)
	if scene.can_strike_escape_wall(): return fail("Strike admitted while aiming above the face")
	await pose(scene, Vector3(1300,32.05,-492), -PI/2, 0.0)
	if scene.can_strike_escape_wall(): return fail("Strike admitted from beyond reach")
	await pose(scene, Vector3(1384.46,32.05,-496.56), -1.75738835334778, -0.054004579782486)
	scene.set_equipped_item("")
	if scene.can_strike_escape_wall(): return fail("Unarmed strike admitted")
	scene.set_equipped_item(scene.SWORD_ITEM_ID)
	# Real left clicks from the owner pose open the wall in three strikes.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for expected in [2,3,4]:
		click()
		await process_frame
		if wall.stage != expected: return fail("Click %d left the wall at stage %d" % [expected-1, wall.stage])
	# Walk straight through the opening; the escape region fires once.
	scene.set_physics_process(true)
	var escaped := false
	for i in range(240):
		await physics_frame
		scene.player.velocity = Vector3(80,-1 if scene.player.is_on_floor() else scene.player.velocity.y-320.0/60,0)
		preload("res://scripts/lol2/walk_step.gd").try_step(scene.player,Vector3(80.0/60,0,0))
		scene.player.move_and_slide()
		if scene.hourglass.escaped: escaped = true
		if escaped and scene.player.position.x > 1460: break
	if not escaped: return fail("Walked to %s without escaping" % scene.player.position)
	print("PASS museum_escape_wall_aim: owner pose shows the strike hint; level gaze at 15 units strikes; looking away, over the top, beyond reach and unarmed refused; three real clicks open the wall; walked through and escaped at x %.1f" % scene.player.position.x)
	scene.queue_free()
	await process_frame
	quit()
