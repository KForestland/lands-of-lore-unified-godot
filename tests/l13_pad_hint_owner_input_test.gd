extends "res://tests/l13_pink_ledge_input_test.gd"
## Owner road, save 04-56-17 (Grok 2026-11-15 11:17Z): at the top of the west stairs beside the upper pad
## (control:53) the screen showed only the key legend. Lead 14:33Z: the pad says what it does. His save by real F9
## from the Citadel F2 start; one disclosed placement at Grok's stairs mark; then: the line is on screen, and real
## W onto the pad takes Luther upstairs (landing region 1166), as the original pad does.
const OWNER := "res://tmp/l13_hint_inputs/owner_045617.json"
const OWNER_SHA := "68b003e00c7b4e6fa8459e3d4ecd8f126075adc1a72310bcd5851b90d1bc66c4"
const MARK := Vector3(-4869.784, -868.579, 1690.13)
const LINE := "Step onto the pad to return upstairs"
func main():
	use_guard = false
	if not require(DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Rendered ordinary-clock pad proof"): return
	if not require(FileAccess.get_sha256(OWNER) == OWNER_SHA, "Untouched owner save 04-56-17"): return
	if not await start_from_f2(): return
	if not require(DirAccess.copy_absolute(ProjectSettings.globalize_path(OWNER), Slots.slot_path(1)) == OK, "Install the owner's save as slot 1"): return
	await tap(KEY_F9); await adopt()
	for i in 30: await physics_frame
	if not captured(): await lclick(); await frames(4)
	scene.player.position = MARK; scene.player.velocity = Vector3.ZERO
	for i in 60: await physics_frame
	var g: Node = scene.get_node("GenericObjects")
	if not require(g.hint.visible and g.hint.text == LINE, "At the stairs top the screen says '%s' (got '%s')" % [LINE, g.hint.text]): return
	await picture("pad_hint_owner")
	var region: Array = scene.progression.regions[987]
	var centre := Vector2.ZERO
	for v: Array in region[0]: centre += Vector2(v[0], v[1])
	centre /= region[0].size()
	var before := pos()
	await look(Vector3(centre.x, pos().y, centre.y))
	for tick in 240:
		turn_step(Vector3(centre.x, scene.camera.global_position.y, centre.y), false)
		key_event(KEY_W, Vector2(pos().x, pos().z).distance_to(centre) > 4.0)
		await physics_frame
		if pos().distance_to(before) > 400.0: break
	key_event(KEY_W, false)
	for i in 30: await physics_frame
	var landing: Array = scene.progression.regions[1166]
	var poly := PackedVector2Array()
	for v: Array in landing[0]: poly.append(Vector2(v[0], v[1]))
	if not require(Geometry2D.is_point_in_polygon(Vector2(pos().x, pos().z), poly) and scene.player.is_on_floor() and hp() > 0, "Real W onto the pad lands upstairs in region 1166 (at %s)" % pos()): return
	if not require(g.hint.text != LINE, "The pad line is gone upstairs"): return
	print("PASS l13_pad_hint_owner_input: owner save, the pad line at the stairs top, real W onto control:53 lands upstairs at ", pos())
	quit()
