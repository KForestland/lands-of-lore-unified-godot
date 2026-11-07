extends SceneTree
## Playtest 2026-10-17 report11-22-24: the owner carried the Fine Longsword but had the cave Stalagmite equipped,
## stood at the hourglass and clicked/pressed E; nothing happened. Original prop226 record4620 and control97 records
## accept melee from any weapon. Owner pose and inventory are reproduced; the real left click is the input.
const STALAGMITE := "cave:prop641:harvest1:Stalagmite"
func _initialize(): run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL museum_hourglass_weapon_admission: ", message); quit(1); return false
func run():
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	var prop = scene.hourglass
	prop.set_process(false)
	# Report camera: global (1334.98,52.04,-631.60), yaw0.0839, pitch-0.1060; the camera sits10 above the body.
	scene.player.position = Vector3(1334.97839355469,42.0416603088379,-631.602416992188)
	scene.player.rotation = Vector3(0,0.0839443877339363,0)
	scene.camera.rotation = Vector3(-0.106018967926502,0,0)
	await physics_frame
	await physics_frame
	if not scene.hourglass_in_reach(): return fail("Owner pose does not reach the hourglass")
	# Owner inventory: both weapons carried, nothing equipped first.
	scene.carried_collected.append(STALAGMITE)
	scene.carried_collected.append(scene.SWORD_ITEM_ID)
	scene.sword_transfer.collect()
	if not scene.set_equipped_item(""): return fail("Could not clear the weapon slot")
	if scene.can_strike_hourglass() or scene.strike_hourglass(): return fail("Unarmed strike admitted")
	scene._physics_process(0.0)
	if not scene.interaction_label.visible or not scene.interaction_label.text.begins_with("Open the inventory (I) and equip your"):
		return fail("No equip hint at the hourglass: '%s'" % scene.interaction_label.text)
	# Cursed forms keep their tested refusal even with a weapon equipped.
	if not scene.set_equipped_item(STALAGMITE): return fail("Stalagmite not equippable in the Museum")
	for form in [1,2]:
		scene.player_form = form
		if scene.can_strike_hourglass(): return fail("Cursed form %d struck with a stored weapon" % form)
	scene.player_form = 0
	scene._physics_process(0.0)
	if scene.interaction_label.text != "Left click — Strike hourglass": return fail("Strike hint missing: '%s'" % scene.interaction_label.text)
	# The owner's exact state: Stalagmite equipped, real left click with a captured mouse.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await process_frame
	if not (prop.activated and prop.active_stage == 0): return fail("Stalagmite click did not start the hourglass")
	if scene.equipped_item != STALAGMITE: return fail("Strike changed the equipped weapon")
	# The escape wall accepts the same weapon (three strikes), then the passage opens.
	var wall = scene.escape_wall
	wall.set_process(false)
	wall.set_stage(1)
	scene.player.position = Vector3(1350,32,-492)
	scene.player.rotation = Vector3.ZERO
	scene.camera.rotation = Vector3.ZERO
	scene.camera.look_at(wall.global_position)
	await physics_frame
	await physics_frame
	for expected in [2,3,4]:
		if not scene.strike_escape_wall() or wall.stage != expected: return fail("Stalagmite wall strike %d refused" % expected)
	if scene.strike_escape_wall(): return fail("Open wall accepted another strike")
	print("PASS museum_hourglass_weapon_admission: owner pose reaches the hourglass; unarmed refused with an equip hint; cursed forms refused; Stalagmite click starts stage0; Stalagmite opens the wall in3 strikes")
	scene.queue_free()
	await process_frame
	quit()
