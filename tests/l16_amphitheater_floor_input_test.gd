extends "res://tests/generic_l13_chain_input_test.gd"
## Grok 2026-11-16 08:25Z STOP and 08:53Z (genuine saves; lead 08:26Z): in the City he fell through the amphitheater floor at
## (-4416.6, 14889.6) and, stepping east off the canal bank, at (-3499.8, 13648.1); the void, then the recovery put him at
## the arrival lift with nothing said. Cause: L16 source walls are drawn only (jungle_review.gd); where a floor stands 80
## or more above the next one (the amphitheater's first tier over its floor, the 130 terrace over the bank's 30 step) the
## 64-high body walked under the raised floor, which has no floor beneath. r19o8: those risers collide; r19o9 (lead
## 10:0xZ): the class - every L16 wall with no standable floor beyond it (height_boundary/L16_CA.json, row 0674); on
## ff6c44e all 43 avenue walls Opus walked by real W fell, six of them are walked here. A fall that still happens says where he wakes. Grok's hourglass F5 (local only) by real
## F9 from the Citadel F2 start; nothing written. Disclosed placements: the amphitheater floor before the tier, Grok's bank
## stand, a void column for the fall line. Real held W at fanned headings; ordinary 1/60.
const SAVE := "res://tmp/l16_canal_inputs/grok_hourglass.json"
const SAVE_SHA := "4962fd6f579b7cea9b8c8d495dd4e4cbb4efff4b51f0d7f740aa06e21ee9f0c7"
const AMPHITHEATER := Vector3(-4444.0, 33.0, 14820.0)   # floor region 4889 (0), riser 22719 north to tier 4913 (80)
const BANK := Vector3(-3754.9, 33.0, 13400.4)           # Grok's 08:53Z stand, floor region 1248 (0)
const VOID := Vector3(-4819.9, -2100.0, 14599.7)        # a column with no floor at all
const FALL_LINE := "You fall and wake at the arrival lift."
## Six of the 40 avenue walls by the arrival that Opus walked by real W on ff6c44e (all 40 fell): terrace risers and fronts.
const AVENUE := [
	[17020, Vector3(-3399.0, 63.0, 3048.0), -1.5708],   # avenue floor 30 into the 130 terrace
	[17021, Vector3(-3306.0, 163.0, 3048.0), -1.5708],  # terrace 130 into a building front (809)
	[17113, Vector3(-3399.0, 63.0, 4710.0), -1.5708],
	[17124, Vector3(-3306.0, 163.0, 4710.0), -1.5708],
	[17176, Vector3(-3306.0, 163.0, 5157.5), -1.5708],
	[17200, Vector3(-3235.0, 497.0, 5369.0), 0.0],      # upper ledge 464 into a front (553)
]
func straight(from: Vector3, yaw: float, ticks: int) -> float:
	scene.player.position = from; scene.player.velocity = Vector3.ZERO
	scene.player.rotation.y = yaw; scene.camera.rotation.x = 0.0
	for i in 20: await physics_frame
	var lowest := pos().y
	key_event(KEY_W, true)
	for i in ticks:
		await physics_frame
		lowest = minf(lowest, pos().y)
	key_event(KEY_W, false)
	await frames(4)
	return lowest
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
	# 1. The amphitheater floor, walking north into the first tier's riser (Grok fell just beyond it).
	for degrees in [0, -30, 30, -60, 60]:
		var low: float = await straight(AMPHITHEATER, PI + deg_to_rad(degrees), 240)
		print("AMPHITHEATER heading %+d: lowest H %.1f, at %s" % [degrees, low, pos()])
		if not require(low > 33.0 - 40.0 and scene.resets == 0, "Amphitheater walk at %+d keeps the feet on a floor (lowest %.1f)" % [degrees, low]): return
	await picture("amphitheater_tier_holds")
	# 2. Grok's bank stand, a straight step east and the headings either side.
	for degrees in [0, -30, 30, -60, 60]:
		var low: float = await straight(BANK, -PI / 2.0 + deg_to_rad(degrees), 300)
		print("BANK heading %+d: lowest H %.1f, at %s" % [degrees, low, pos()])
		if not require(low > 33.0 - 40.0 and scene.resets == 0, "Bank walk at %+d keeps the feet on a floor (lowest %.1f)" % [degrees, low]): return
	await picture("bank_terrace_holds")
	# 3. The avenue by the arrival: terrace risers and building fronts hold.
	for row in AVENUE:
		var from: Vector3 = row[1]
		var low: float = await straight(from, float(row[2]), 180)
		print("AVENUE wall %d: lowest H %.1f, at %s" % [row[0], low, pos()])
		if not require(low > from.y - 40.0 and scene.resets == 0, "Avenue wall %d holds (lowest %.1f)" % [row[0], low]): return
	await picture("avenue_front_holds")
	# 4. A fall that still happens is said.
	scene.player.position = VOID; scene.player.velocity = Vector3.ZERO
	for i in 10: await physics_frame
	if not require(scene.resets == 1 and pos().distance_to(scene.start) < 40.0 and hud() == FALL_LINE, "After a fall he wakes at the arrival lift and is told (resets %d, at %s, got '%s')" % [scene.resets, pos(), hud()]): return
	print("PASS l16_amphitheater_floor_input: Grok's save: the amphitheater tier and the bank terrace hold at five headings each; six avenue terraces and fronts hold; a fall says where he wakes")
	quit()
