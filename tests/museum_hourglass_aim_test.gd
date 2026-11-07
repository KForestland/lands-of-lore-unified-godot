extends SceneTree
## Owner r3 afternoon 2026-10-20: "tried but did not have sword to hit the hourglass". The old admission aimed at
## one point 31 above the base (11 below eye height) within a 14-degree cone, so a level gaze from ~20 units was
## refused. Original prop226 g4620 takes melee wherever the hourglass is aimed. Natural poses, no look_at.
const SHORT_SWORD := "cave:captain:Short_Sword"
func _initialize(): run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL museum_hourglass_aim: ", message); quit(1); return false
func pose(scene, position: Vector3, yaw: float, pitch: float) -> void:
	scene.player.position = position
	scene.player.rotation = Vector3(0,yaw,0)
	scene.camera.rotation = Vector3(pitch,0,0)
	await physics_frame
	await physics_frame
func hint(scene) -> String:
	scene._physics_process(0.0)
	return scene.interaction_label.text if scene.interaction_label.visible else ""
func run():
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.hourglass.set_process(false)
	# Level gaze, facing the hourglass from 20 units (base at y10, camera 10 above the body).
	await pose(scene, Vector3(1332,42.04,-643), 0.0, 0.0)
	if not scene.hourglass_in_reach(): return fail("Level gaze from 20 units does not reach the hourglass")
	# Unarmed with nothing carried: told a weapon is needed.
	if hint(scene) != "You need a weapon to strike the hourglass": return fail("Empty-handed hint: '%s'" % hint(scene))
	# Carrying the cave Short Sword but not holding it: told to equip it from the inventory.
	scene.carried_collected.append(SHORT_SWORD)
	if hint(scene) != "Open the inventory (I) and equip your Short Sword to strike the hourglass":
		return fail("Carried-sword hint: '%s'" % hint(scene))
	if scene.can_strike_hourglass(): return fail("Unequipped strike admitted")
	if not scene.set_equipped_item(SHORT_SWORD): return fail("Cave Short Sword not equippable in the Museum")
	# Cursed forms still refused, with a form hint.
	scene.player_form = 1
	if scene.can_strike_hourglass(): return fail("Cursed form struck")
	if hint(scene) != "You cannot wield a weapon in this form": return fail("Cursed hint: '%s'" % hint(scene))
	scene.player_form = 0
	if hint(scene) != "Left click — Strike hourglass": return fail("Strike hint: '%s'" % hint(scene))
	# Off-centre aim on the sprite still counts; looking away, over the top and beyond reach do not.
	await pose(scene, Vector3(1332,42.04,-643), 0.0, -0.6)
	if not scene.can_strike_hourglass(): return fail("Aim at the lower sprite refused")
	await pose(scene, Vector3(1332,42.04,-643), PI/2, 0.0)
	if scene.can_strike_hourglass(): return fail("Strike admitted while looking away")
	await pose(scene, Vector3(1332,42.04,-643), 0.0, 1.2)
	if scene.can_strike_hourglass(): return fail("Strike admitted while aiming above the sprite")
	await pose(scene, Vector3(1332,42.04,-560), 0.0, 0.0)
	if scene.can_strike_hourglass(): return fail("Strike admitted from beyond reach")
	# Real left click from the natural pose starts the hourglass.
	await pose(scene, Vector3(1332,42.04,-643), 0.0, 0.0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	if not scene.hourglass.activated: return fail("Left click from a level gaze did not start the hourglass")
	print("PASS museum_hourglass_aim: level gaze at 20 units reaches; hints: need-weapon / equip carried Short Sword / cursed form / strike; off-centre aim admitted; away, over the top and beyond reach refused; real click starts the hourglass")
	scene.queue_free()
	await process_frame
	quit()
