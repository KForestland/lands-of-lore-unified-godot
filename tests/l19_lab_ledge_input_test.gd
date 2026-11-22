extends "res://tests/generic_l13_chain_input_test.gd"
## Grok 2026-11-16 19:02Z (owner road, r19o8): in Belial's Laboratory every heading off the ramp at (-217, -1378) but one
## left the floor and fell to H -344 (the ramp's south side, wall 7181, is drawn only below the walking surface). From Grok's
## game-written save (local only) by real F9 and real held W: the ramp names the turn, and the three headings he and the
## probe took (south-west, east, and straight at his road point) stay on the ramp floor. Pose at the ramp is a test aid.
const SAVE := "res://tmp/l19_bow_inputs/grok_cb34052f.json"
func main():
	use_guard = false
	if not require(DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Rendered ordinary-clock proof"): return
	if not require(FileAccess.get_sha256(SAVE) == "cb34052f0bc56c41b29a95b6f3c8d84d9e9ef676cc1a8aaef1867bd621a128ad", "Untouched Grok save"): return
	if not await start_from_f2(): return
	DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
	DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE), Slots.slot_path(1))
	await tap(KEY_F9); await adopt()
	for i in 30: await physics_frame
	if not captured(): await lclick(); await frames(4)
	for target in [Vector2(-232.5,-1446.5), Vector2(231.7,-1448.0), Vector2(-217.3,-1499.6)]:
		scene.player.position = Vector3(-217.3, 32.0, -1378.5); scene.player.velocity = Vector3.ZERO
		scene.player.rotation.y = atan2(-(target.x - -217.3), -(target.y - -1378.5)); scene.camera.rotation.x = 0
		for i in 20: await physics_frame
		if not require(scene.get_node("L19LabLedge").hint.text == "The corridor turns at the west end of the ramp", "The ramp names the turn"): return
		key_event(KEY_W, true)
		for t in 150: await physics_frame
		key_event(KEY_W, false)
		print("END toward ", target, " at ", scene.player.position.round(), " floor ", scene.player.is_on_floor())
		if not require(scene.player.position.y > 20.0 and scene.player.is_on_floor() and scene.resets == 0, "Held W toward %s stays on the ramp (at %s)" % [target, scene.player.position]): return
	print("PASS l19_lab_ledge_input: the ramp names the turn; held W south-west, east and south stays on the ramp")
	quit()
