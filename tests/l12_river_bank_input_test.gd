extends "res://tests/generic_l13_chain_input_test.gd"
## Owner F10 2026-11-16T16-27-05 (r19o8, lead pick B): back from the Citadel with the Dreamstone he rode the ice floe,
## five plain jumps beside the glacier bank fell short, and he stood in the river bed under a 55-67 degree snow bank with
## no way up and nothing said. His save never had the glacier collapse. Proof from HIS save (local only), real keys and
## mouse, plain W (no Shift), Space only where the walk stalls; ordinary 1/60:
##  1. the river-bed line names the way, held W walks up the snow-bank steps onto the bank (-1090);
##  2. on to the log stair and up it to the upper floor (914/915) - the glacier never fell in his save;
##  3. back down, across the ice bridge to its far end (3000, -13000);
##  4. a floe passing the bank: the floe line shows, plain W steps off and walks up onto the bank (three tries allowed).
## Disclosed aids: for 3 the body is set back at his stop in the river bed; for 4 it is set on a floe deck about 1000
## before the bank (one pose per try), like a boarding.
const SAVE := "res://tmp/l12_river_inputs/owner_162705.json"
const SAVE_SHA := "ca4b9f58ac53964894377d568a7953577bc7c04004897f9e7de3fd89fc70be42"
const BANK_LINE := "Walk up the snow bank to the ice bridge"
const FLOE_LINE := "Step off the floe here and walk up the snow bank"
func feet() -> float: return pos().y - 32.0
## Onto a log top by plain keys (no Shift): a higher log W held and Space tapped, a lower one W only (owner 16-33-44:
## "jump down and jump up on the brown tree things"); landed when back on a floor near it.
func hop(target: Vector3, what: String) -> bool:
	for attempt in 3:
		await look(Vector3(target.x, pos().y + 8, target.z))
		key_event(KEY_W, true); await physics_frame
		if target.y > pos().y - 4.0: key_event(KEY_SPACE, true); await physics_frame; key_event(KEY_SPACE, false)
		var airborne := false
		for tick in 240:
			var d := Vector3(target.x - pos().x, 0, target.z - pos().z)
			key_event(KEY_W, d.length() > 4.0)
			await physics_frame
			if not scene.player.is_on_floor(): airborne = true
			if airborne and scene.player.is_on_floor(): break
		key_event(KEY_W, false)
		for i in 4: await physics_frame
		var near := Vector2(pos().x - target.x, pos().z - target.z).length()
		print("HOP %s try %d at %s (target %s, %.0f away)" % [what, attempt + 1, pos().round(), target.round(), near])
		if absf(pos().y - target.y) < 6.0 and near < 40.0 and scene.resets == 0: return true
		if pos().y > -562.0 and scene.player.is_on_floor() and scene.resets == 0: return true # already on the upper floor
		if pos().y < target.y - 60.0: break
	return require(false, "Plain jump onto %s (at %s)" % [what, pos()])
func main():
	use_guard = false
	avoid_fights = true
	if not require(DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Rendered ordinary-clock proof"): return
	if not require(FileAccess.get_sha256(SAVE) == SAVE_SHA, "Untouched owner save 16-27-05 (got %s)" % FileAccess.get_sha256(SAVE)): return
	if not await start_from_f2(): return
	DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
	if not require(DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE), Slots.slot_path(1)) == OK, "Install his save as slot 1"): return
	await tap(KEY_F9); await adopt()
	for i in 30: await physics_frame
	if not captured(): await lclick(); await frames(4)
	if not require(scene.area_id == "L12_CM" and absf(feet() + 1190.0) < 4.0, "His save: in the river bed (at %s)" % pos()): return
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	if not require(not saved.area_save.quests.has("l12_glacier"), "His save never had the glacier collapse"): return
	var bank: Node = scene.get_node("L12RiverBank")
	await frames(2)
	if not require(bank.hint.text == BANK_LINE, "The river bed names the way (got '%s')" % bank.hint.text): return
	# 1. Up the snow bank from his own stop.
	if not await walk([[3150, -12110]], "snow bank"): return
	print("BANK reached ", pos())
	if not require(feet() > -1095.0 and scene.player.is_on_floor() and scene.resets == 0, "Held W from the river bed onto the bank (at %s)" % pos()): return
	# 2. The log stair to the upper floor, plain keys.
	var approach: Array = fixture("l12_logs_approach.json")
	if not await walk(approach, "log approach"): return
	var logs: Array = fixture("l12_return_logs.json")
	for row in logs:
		if int(row.id) in [53, 52]: continue # step onto the upper floor after log55, as the earned climb
		if pos().y > -562.0 and scene.player.is_on_floor(): break
		if not await hop(Vector3(row.point[0], row.point[1] + 32, row.point[2]), "log %d" % int(row.id)): return
	if pos().y < -562.0 and not await hop(Vector3(3500, -558, -11570), "upper floor"): return
	print("UPPER ", pos())
	if not require(feet() > -600.0 and scene.player.is_on_floor() and scene.resets == 0, "Up the log stair onto the upper floor (at %s)" % pos()): return
	# 3. The ice bridge from the bank to its far end: back to the bank (as the river bed), then across.
	scene.player.position = Vector3(3049, -1158, -12201); scene.player.velocity = Vector3.ZERO
	for i in 20: await physics_frame
	if not await walk([[3150, -12110], [3190, -12120], [3250, -12235], [3250, -12255], [3202, -12313], [3114, -12454], [3037, -12602], [2990, -12750], [3000, -13000]], "ice bridge"): return
	print("BRIDGE far end ", pos())
	if not require(feet() > -1095.0 and scene.resets == 0, "Across the ice bridge (at %s)" % pos()): return
	# 4. A floe beside the bank: plain W+Space, at most three tries.
	var rafts: Node = scene.get_node("L12RiverRafts")
	var landed := false
	for attempt in 3:
		var boat := -1
		for wait in 6000:
			for i in 3:
				var c: Vector3 = rafts.centre(i)
				if c.z > -13944 and Vector2(c.x, c.z).distance_to(Vector2(3110, -12150)) < 1100.0 and Vector2(c.x, c.z).distance_to(Vector2(3110, -12150)) > 900.0 and c.x > 3200: boat = i
			if boat >= 0: break
			await physics_frame
		if not require(boat >= 0, "A floe comes toward the bank"): return
		var at: Vector3 = rafts.centre(boat)
		scene.player.position = at + Vector3(0, 32 + 2, 0); scene.player.velocity = Vector3.ZERO
		for i in 10: await physics_frame
		var shown := 0
		for tick in 900:
			await physics_frame
			if bank.hint.text == FLOE_LINE: shown += 1
			if shown >= 15: break # a quarter second to read the line
		shown = 1 if shown >= 15 else 0
		print("FLOE ", attempt, " line ", shown, " at ", pos(), " riding ", rafts.riding())
		if not require(shown == 1 and rafts.riding() >= 0, "Riding a floe past the bank shows '%s'" % FLOE_LINE): return
		# He steps off where the line says (9 down into the river bed) and walks up the snow bank: W only.
		await walk([[3150, -12110]], "floe to bank")
		print("FLOE WALK ", attempt, " at ", pos())
		if feet() > -1095.0: landed = true; break
	if not require(landed, "From the floe where the line shows, plain W reaches the bank within three tries"): return
	print("PASS l12_river_bank_input: from his save the river bed says the way and held W walks up the snow bank; the log stair to the upper floor; the ice bridge; from a floe, plain W onto the bank")
	quit()
