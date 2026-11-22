extends "res://tests/generic_l13_chain_input_test.gd"
## Step class (lead 2026-11-16, r19p). Grok 11:10Z, arrival-avenue arcade at Y 5720: walking east from (-3481.5, 5716.9)
## the body fell 5 of 5 - the 0 -> 30 risers 17230/17235 are drawn only, so walk_step never fired and the body slid under
## the arcade floor. Risers of 31 or less between two static floors now collide (height_boundary/L16_CA.json) and the body
## steps up. Grok's hourglass F5 (local only); real held W, ordinary 1/60. Disclosed placements: Grok's stand, and for 12
## risers sampled across the City (tests/fixtures/l16_step_risers.json) a stand 24 out on the low side and on the high side.
const SAVE := "res://tmp/l16_canal_inputs/grok_hourglass.json"
const SAVE_SHA := "4962fd6f579b7cea9b8c8d495dd4e4cbb4efff4b51f0d7f740aa06e21ee9f0c7"
func go(from: Vector3, dir: Vector2, ticks: int) -> Dictionary:
	scene.player.position = from; scene.player.velocity = Vector3.ZERO
	scene.player.rotation.y = atan2(-dir.x, -dir.y); scene.camera.rotation.x = 0.0
	for i in 15: await physics_frame
	var r0: int = scene.resets
	var lowest := pos().y
	key_event(KEY_W, true)
	for i in ticks:
		await physics_frame
		lowest = minf(lowest, pos().y)
	key_event(KEY_W, false)
	for i in 8: await physics_frame
	return {"end": pos(), "lowest": lowest, "reset": scene.resets > r0}
func main():
	use_guard = false
	if not require(DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Rendered ordinary-clock proof"): return
	if not require(FileAccess.get_sha256(SAVE) == SAVE_SHA, "Untouched Grok hourglass save"): return
	if not await start_from_f2(): return
	DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
	if not require(DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE), Slots.slot_path(1)) == OK, "Install Grok's save as slot 1"): return
	await tap(KEY_F9); await adopt()
	for i in 30: await physics_frame
	if not captured(): await lclick(); await frames(4)
	if not require(scene.area_id == "L16_CA", "His save: the City (got %s)" % scene.area_id): return
	for deg in [0, -30, 30, -60, 60]:
		var a := deg_to_rad(deg)
		var r: Dictionary = await go(Vector3(-3481.5, 33.0, 5716.9), Vector2(cos(a), sin(a)), 120)
		print("Y5720 heading %+d end %s lowest %.1f" % [deg, r.end, r.lowest])
		if not require(not r.reset and r.lowest > 20.0, "Y 5720 arcade step at %+d: no fall (lowest %.1f)" % [deg, r.lowest]): return
		if deg == 0 and not require(r.end.y > 60.0, "Straight east he steps up onto the 30 floor (end %s)" % r.end): return
	await picture("y5720_arcade_step")
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l16_step_risers.json"))
	for row in rows:
		var mid := Vector2(row.mid[0], row.mid[1]); var n := Vector2(row.n[0], row.n[1])
		var low := mid - n * 24.0; var high := mid + n * 24.0
		var up: Dictionary = await go(Vector3(low.x, float(row.lo) + 33.0, low.y), n, 50)
		var up_gain: float = Vector2(up.end.x - low.x, up.end.z - low.y).dot(n)
		if not require(not up.reset and up_gain >= 30.0 and up.lowest > float(row.lo) + 12.0, "Riser %d (%d -> %d) steps up (gain %.1f, lowest %.1f)" % [row.face, row.lo, row.hi, up_gain, up.lowest]): return
		var down: Dictionary = await go(Vector3(high.x, float(row.hi) + 33.0, high.y), -n, 50)
		var down_gain: float = Vector2(down.end.x - high.x, down.end.z - high.y).dot(-n)
		if not require(not down.reset and down_gain >= 30.0 and down.lowest > float(row.lo) + 12.0, "Riser %d steps down (gain %.1f, lowest %.1f)" % [row.face, down_gain, down.lowest]): return
	print("PASS l16_step_riser_input: Y 5720 arcade holds at five headings and steps up; %d sampled risers up and down" % rows.size())
	quit()
