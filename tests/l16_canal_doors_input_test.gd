extends "res://tests/generic_l13_chain_input_test.gd"
## Grok 2026-11-16 12:10Z/12:38Z on r19o9 (genuine hourglass F5): the City's canal doors opened on E but the screen named
## no action; past door pair 158/159 the body wedged at (-516.5, 12623.2) between the doorway's north frame and the opened
## leaf 159, which turned about its middle and left 25 / 50 / 25 gaps across the 100-wide doorway. Fix (lead 2026-11-16,
## pick A): each canal leaf turns at its outer end (the frame), so an open pair clears the whole doorway; walls unchanged.
## Proof by real input from Grok's hourglass F5 (local only): faced closed pair shows 'E — Open the door', real E opens it
## and the line goes; then real held W through the top, middle and bottom of all 24 canal doorways, and Grok's own line
## from his stop to fixture point 137. Disclosed: the other 23 pairs are opened by the same use() E calls, and each
## walk starts from a placement 40 east of the door line. Ordinary 1/60.
const SAVE := "res://tmp/l16_canal_inputs/grok_hourglass.json"
const SAVE_SHA := "4962fd6f579b7cea9b8c8d495dd4e4cbb4efff4b51f0d7f740aa06e21ee9f0c7"
const PROMPT := "E — Open the door"
func place(at: Vector3, toward: Vector3) -> void:
	scene.player.position = at; scene.player.velocity = Vector3.ZERO
	scene.player.rotation.y = atan2(-(toward.x - at.x), -(toward.z - at.z)); scene.camera.rotation.x = 0.0
	for i in 15: await physics_frame
func hold_w(ticks: int) -> void:
	key_event(KEY_W, true)
	for i in ticks: await physics_frame
	key_event(KEY_W, false)
	for i in 6: await physics_frame
func door_line(id: int) -> Vector3:
	var a: Vector3 = scene.progression.hinge_origin[id]
	var b: Vector3 = scene.progression.hinge_origin[id ^ 1]
	return Vector3(a.x, 33.0, (a.z + b.z) * 0.5)
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
	var prog: Node = scene.progression
	# 1. A closed pair names its action; real E opens it and the line goes.
	if not require(int(prog.travel.get(158, 0)) == 0 and int(prog.travel.get(159, 0)) == 0, "Pair 158/159 starts closed"): return
	var c158 := door_line(158)
	await place(c158 + Vector3(60, 0, 0), c158)
	for i in 4: await physics_frame
	if not require(prog.interaction_hint.text == PROMPT, "Facing the closed canal door says '%s' (got '%s')" % [PROMPT, prog.interaction_hint.text]): return
	await tap(KEY_E)
	for i in 90: await physics_frame
	if not require(int(prog.travel.get(158, 0)) != 0 and int(prog.travel.get(159, 0)) != 0, "Real E opens both leaves"): return
	if not require(prog.interaction_hint.text == "", "The open door no longer asks (got '%s')" % prog.interaction_hint.text): return
	await picture("canal_door_open_frame_hinged")
	# 2. Grok's own line: from his stop toward fixture point 137.
	await place(Vector3(-516.5, 33.0, 12623.2), Vector3(-675.0, 33.0, 12575.0))
	await hold_w(180)
	print("GROK LINE end ", pos())
	if not require(pos().x < -620.0 and scene.resets == 0, "From Grok's stop he walks on toward point 137 (end %s)" % pos()): return
	# 3. Top, middle and bottom of every canal doorway, westward through the door line.
	var passed := 0
	for first in range(122, 170, 2):
		if int(prog.travel.get(first, 0)) == 0: prog.use(first)
		for i in 90: await physics_frame
		if not require(int(prog.travel.get(first, 0)) != 0 and int(prog.travel.get(first + 1, 0)) != 0, "Pair %d/%d opens" % [first, first + 1]): return
		var line := door_line(first)
		for dz in [-35.0, 0.0, 35.0]:
			var from := line + Vector3(40, 0, dz)
			await place(from, line + Vector3(-80, 0, dz))
			await hold_w(120)
			var through: bool = pos().x < line.x - 40.0 and absf(pos().z - from.z) < 12.0 and scene.resets == 0
			print("DOOR %d/%d dz %+d end %s %s" % [first, first + 1, dz, pos(), "through" if through else "STOPPED"])
			if not require(through, "Pair %d/%d at %+d crosses the doorway (end %s)" % [first, first + 1, dz, pos()]): return
			passed += 1
	print("PASS l16_canal_doors_input: closed canal door says '%s', real E opens it; Grok's line to point 137 and %d doorway walks (24 pairs x top/middle/bottom) pass" % [PROMPT, passed])
	quit()
