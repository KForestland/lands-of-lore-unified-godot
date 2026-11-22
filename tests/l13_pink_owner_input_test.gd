extends "res://tests/l13_pink_ledge_input_test.gd"
## Owner stop, save 04-56-17 on r19o (Grok 2026-11-15 12:07Z): treads 0 and 1 landed, then five jumps
## left him hanging short of tread 2 at (-3011, 384, H -866) with nothing on screen. His save is loaded
## by real F9 from the Citadel F2 start; then one disclosed placement on tread 1's landing (his route there
## is the ordinary stair walk, proven elsewhere). Lead standard 2026-11-15 14:33Z: from a standing start on
## each tread, real W/Space lands the next within three jumps, treads 2-20, from his save AND from the actual
## F2 pink-base slot, without and with Shift; ordinary 1/60, no resets. No knife-edge passes.
const OWNER := "res://tmp/l13_hint_inputs/owner_045617.json"
const OWNER_SHA := "68b003e00c7b4e6fa8459e3d4ecd8f126075adc1a72310bcd5851b90d1bc66c4"
const BASE := "res://tmp/g03_l13_inputs/pink_base_f5.json"
const BASE_SHA := "2564c6e32af3fda29a688d19e4c2f38873759549ab92e6a8ce9a2c87402e6195"
func main():
	use_guard = false
	if not require(DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Rendered ordinary-clock owner pink proof"): return
	if not require(FileAccess.get_sha256(OWNER) == OWNER_SHA, "Untouched owner save 04-56-17"): return
	if not require(FileAccess.get_sha256(BASE) == BASE_SHA, "Untouched actualF5 pink-base slot"): return
	route = fixture("l13_pink_steps_walk.json")
	if not await start_from_f2(): return
	for run in [[OWNER, false], [OWNER, true], [BASE, false], [BASE, true]]:
		if not await climb(str(run[0]), bool(run[1])): return
	print("PASS l13_pink_owner_input: owner save 04-56-17 and the F2 pink-base slot, real W/Space with and without Shift, treads 2-20 each within three jumps from a standing start, wedge releases ", scene.get_meta("pink_wedge_releases", 0))
	quit()

var route: Dictionary
func climb(slot: String, shift: bool) -> bool:
	var tag := slot.get_file().get_basename() + (" +Shift" if shift else " plain")
	if not require(DirAccess.copy_absolute(ProjectSettings.globalize_path(slot), Slots.slot_path(1)) == OK, "Install " + tag + " as slot 1"): return false
	await tap(KEY_F9); await adopt()
	for i in 30: await physics_frame
	if not captured(): await lclick(); await frames(4)
	if not require(area == "L13_RC" and hp() > 0, tag + " loads living in the Citadel"): return false
	var first: Dictionary = route.steps[1]
	var start := landing(first)
	scene.player.position = Vector3(start.x, float(first.height) + 40.0, start.y); scene.player.velocity = Vector3.ZERO
	for i in 60: await physics_frame
	if not require(scene.player.is_on_floor() and absf(pos().y - 32.0 - float(first.height)) < 1.0, tag + " standing on tread 1"): return false
	for index in range(2, route.steps.size()):
		var step: Dictionary = route.steps[index]
		var target := landing(step)
		var landed := false
		var tries := 0
		for attempt in 3:
			tries = attempt + 1
			key_event(KEY_W, false)
			for tick in 120:
				if scene.player.is_on_floor(): break
				await physics_frame
			await look(Vector3(target.x, pos().y, target.y))
			key_event(KEY_W, true); key_event(KEY_SHIFT, shift)
			for tick in 6: await physics_frame
			key_event(KEY_SPACE, true); await physics_frame; key_event(KEY_SPACE, false)
			for tick in 120:
				var delta := target - Vector2(pos().x, pos().z)
				turn_step(Vector3(target.x, scene.camera.global_position.y, target.y), false)
				key_event(KEY_W, delta.length() > 1.5); key_event(KEY_SHIFT, shift and delta.length() > 1.5)
				await physics_frame
				if scene.resets != 0 or hp() <= 0: break
				if scene.player.is_on_floor() and pos().y - 32.0 >= float(step.height) - 8.0 and delta.length() < 12.0:
					landed = true; break
			key_event(KEY_W, false); key_event(KEY_SHIFT, false)
			if landed or scene.resets != 0 or hp() <= 0: break
		print("PINK ", tag, " step=", index, " tries=", tries, " landed=", landed, " position=", pos(), " releases=", scene.get_meta("pink_wedge_releases", 0))
		if not landed:
			await picture("pink_owner_stop_" + slot.get_file().get_basename() + ("_shift_" if shift else "_plain_") + str(index))
			if not require(false, tag + ": real W/Space reaches pink tread %d within three jumps" % index): return false
	return require(scene.resets == 0 and hp() > 0, tag + " climb stays living without recovery")

func landing(step: Dictionary) -> Vector2:
	var region: Array = scene.progression.regions[int(step.region)]
	var poly := PackedVector2Array()
	for vertex: Array in region[0]: poly.append(Vector2(vertex[0], vertex[1]))
	var edge := Vector2(step.point[0], step.point[1])
	var inner := poly[1].lerp(poly[2], 0.1)
	return edge + (inner - edge).normalized() * 8.0
