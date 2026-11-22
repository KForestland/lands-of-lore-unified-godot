extends "res://tests/helpers/real_input_player.gd"
## Grok r19o3 owner-save walk 2026-11-15 19:20Z: arriving from the Citadel (native arrival selector 2) and holding W, the
## body walked through the passage's null-edge wall 7896 onto no floor and fell from H -1198 to below -2300. Lead: a blocker
## at the lip, one level (height_boundary/L12_CM.json, DEVIATIONS row 0669). The owner's own L12 save (g05_ruloi) by the
## save loader; disclosed placement: the native selector-2 arrival, at seven headings fanned 60 degrees either side of the
## heading Grok walked. Real held W only; ordinary 1/60. Each walk must keep the feet on the passage floor.
const SAVE := "res://tests/fixtures/g05_ruloi/owner_06-47-40_save.json"
const ARRIVAL := Vector3(3211.0, -1198.0, -18903.0)
const GROK_YAW := 3.0 * PI / 4.0 # the walk toward (2373, -18064)
func _initialize(): main.call_deferred()
func main():
	use_guard = false
	set_meta("original_game_verified", true)
	if DisplayServer.get_name() == "headless" or Engine.time_scale != 1.0 or Engine.physics_ticks_per_second != 60:
		print("FAIL l12_citadel_lip: rendered ordinary clock needed"); quit(1); return
	var error: String = load("res://scripts/lol2/game_save.gd").load_file(self, ProjectSettings.globalize_path(SAVE))
	if not error.is_empty(): print("FAIL l12_citadel_lip: ", error); quit(1); return
	await adopt()
	if area != "L12_CM": print("FAIL l12_citadel_lip: arrived in ", area); quit(1); return
	if not captured(): await lclick(); await frames(4)
	var failed := 0
	for degrees in [0, -20, 20, -40, 40, -60, 60]:
		scene.player.position = ARRIVAL; scene.player.velocity = Vector3.ZERO
		scene.player.rotation.y = GROK_YAW + deg_to_rad(degrees); scene.camera.rotation.x = 0.0
		for i in 20: await physics_frame
		var lowest := pos().y
		key_event(KEY_W, true)
		for tick in 900:
			await physics_frame
			lowest = minf(lowest, pos().y)
			if lowest < ARRIVAL.y - 80.0: break
		key_event(KEY_W, false)
		await frames(4)
		var ok := lowest >= ARRIVAL.y - 80.0
		print("LIP heading %+d: %s, lowest H %.1f, ended at %s" % [degrees, "on the floor" if ok else "FELL", lowest, pos()])
		if not ok: failed += 1
	if failed > 0:
		print("FAIL l12_citadel_lip: %d of 7 straight walks from the Citadel arrival left the passage floor" % failed); quit(1); return
	print("PASS l12_citadel_lip: seven straight W walks from the Citadel arrival stay on the passage floor")
	quit(0)
