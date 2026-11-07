extends SceneTree
## Draracle-wing bars (docs/museum-draracle-bars.md): actual capsule walk into region1174 runs g1364 once (bars 71-74
## rise 100 with native travel arithmetic, local17 1, gate77 closes); the raised bars stop a westward walk that passes
## while they are down; checkpoint/save round trip mid-travel; control79 E at local19 2 plays sound394 then sound312.
const Bars = preload("res://scripts/lol2/museum_draracle_bars.gd")
const MovementState = preload("res://scripts/lol2/cave_guard_movement_state.gd")
const Save = preload("res://scripts/lol2/museum_save.gd")
func _initialize() -> void:
	_run.call_deferred()

func fail(message: String) -> void:
	push_error(message); print("FAIL " + message); quit(1)

func make_scene() -> Node3D:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	scene.sword_transfer.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await settle(scene)
	return scene

func settle(scene: Node3D) -> void:
	for i in range(30):
		await physics_frame
		scene.player.velocity = Vector3(0,-80,0)
		scene.player.move_and_slide()

func place(scene: Node3D, x: float, z: float, yaw: float) -> void:
	scene.player.position = Vector3(x, scene.player.position.y + 4, z)
	scene.player.rotation = Vector3(0, yaw, 0)
	scene.camera.rotation = Vector3.ZERO
	await settle(scene)
	scene.draracle_bars.sync_inside(scene.player.position, scene.player.position.y - 32.0, scene.player.is_on_floor())

## Actual capsule walk along +x/-x; the host's own bar step runs each physics frame.
func walk(scene: Node3D, vx: float, frames: int) -> void:
	for i in range(frames):
		await physics_frame
		scene.player.velocity = Vector3(vx, -1 if scene.player.is_on_floor() else scene.player.velocity.y - 320.0/60, 0)
		scene.player.move_and_slide()
		scene.draracle_bars.step(1.0/60.0, scene.player.position, scene.player.position.y - 32.0, scene.player.is_on_floor())

func bar_y(scene: Node3D, id: int) -> float:
	return scene.draracle_bars.movement.bodies[str(id)].position.y

func _run() -> void:
	var src := Bars.source()
	if src.bars.ids.map(func(v): return int(v)) != [71, 72, 73, 74] or src.movables.size() != 4: return fail("Source contract")
	var scene = await make_scene()
	if not is_instance_valid(scene.draracle_bars): return fail("Bars owner missing")
	# The wheel door (control80) closes doorway region1232 just west of the bar line; unlink it so only the bars block.
	if is_instance_valid(scene.get("wheel_door")): scene.wheel_door.restore({"version":1, "state":2, "clock":0.0})
	for id in src.bars.ids.map(func(v): return int(v)):
		if absf(bar_y(scene, id) + 120.0) > 0.01: return fail("Bar %d not down at start" % id)
	# Control (bars down): a westward walk from the hall passes the bar line at x=-3789.
	await place(scene, -3700, -1088, -PI/2)
	await walk(scene, -80, 90)
	if scene.player.position.x > -3800: return fail("Control walk did not pass the lowered bar line (x=%.1f)" % scene.player.position.x)
	if scene.draracle_bars.local17 != 0: return fail("Walking west of region1174 ran g1364")
	# Gate77 open (sword sequence finished) so its source close is observable.
	scene.museum_gate.open()
	for i in range(80): scene.museum_gate.advance(1.0/60.0)
	if scene.museum_gate.progress < 1.0: return fail("Gate77 did not open for the fixture")
	# Actual walk east into region1174: g1364 once.
	await walk(scene, 80, 200)
	if scene.player.position.x < -3672: return fail("Walk did not reach region1174 (x=%.1f)" % scene.player.position.x)
	if scene.draracle_bars.local17 != 1 or scene.museum_gate.target_open: return fail("Region1174 entry did not run g1364")
	var mid: Dictionary = scene.draracle_bars.checkpoint()
	for id in src.bars.ids.map(func(v): return int(v)):
		if int(mid.movement.objects[str(id)].target) != 100 * 65536: return fail("Bar %d target is not travel100" % id)
	# Native percent arithmetic: target = travel*100//100; speed byte40 -> 100 units per 60 ticks.
	await walk(scene, 0, 70)
	for id in src.bars.ids.map(func(v): return int(v)):
		if absf(bar_y(scene, id) + 20.0) > 0.01: return fail("Bar %d did not rise to -20 (y=%.2f)" % [id, bar_y(scene, id)])
	if not scene.draracle_bars.bars_raised(): return fail("bars_raised false after travel")
	# One-shot: leaving and re-entering runs nothing more.
	var done: Dictionary = scene.draracle_bars.checkpoint()
	await walk(scene, -80, 40)
	await walk(scene, 80, 60)
	if scene.draracle_bars.checkpoint() != done: return fail("Region1174 re-entry changed the bars")
	# Raised bars stop the same westward walk.
	await place(scene, -3700, -1088, -PI/2)
	await walk(scene, -80, 90)
	if scene.player.position.x < -3790: return fail("Raised bars did not block the bar line (x=%.1f)" % scene.player.position.x)
	# Save round trip mid-travel and refusals.
	var state: Dictionary = scene.capture_exhibit_retry()
	if Save.validate(state).is_empty() == false: return fail("Raised-bar save rejected: " + Save.validate(state))
	if state.checkpoint.museum_draracle_bars != done: return fail("Save does not carry the bars")
	var moving: Dictionary = state.duplicate(true)
	moving.checkpoint.museum_draracle_bars = mid
	if not Save.validate(moving).is_empty(): return fail("Mid-travel save rejected")
	scene.apply_save(moving)
	if absf(bar_y(scene, 71) - (-120.0 + float(mid.movement.objects["71"].current) / 65536.0)) > 0.01: return fail("Mid-travel restore pose")
	await walk(scene, 0, 70)
	if not scene.draracle_bars.bars_raised(): return fail("Restored travel did not finish")
	var bad_states := [{}, [], {"version":1,"local17":2,"movement":done.movement}, {"version":2,"local17":1,"movement":done.movement},
		{"version":1,"local17":0,"movement":done.movement}, {"version":1,"local17":1,"movement":{}}, {"version":1,"local17":1,"movement":done.movement,"x":0}]
	for bad in bad_states:
		var copy: Dictionary = state.duplicate(true)
		copy.checkpoint.museum_draracle_bars = bad
		if Save.validate(copy).is_empty(): return fail("Accepted bad bars state " + str(bad))
	var legacy: Dictionary = state.duplicate(true)
	legacy.checkpoint.erase("museum_draracle_bars")
	if not Save.validate(legacy).is_empty(): return fail("Legacy save rejected")
	scene.apply_save(legacy)
	if scene.draracle_bars.local17 != 0 or absf(bar_y(scene, 72) + 120.0) > 0.01: return fail("Legacy save did not restore bars down")
	# Control79 (g6976/g6998): refused before local19 2, with a held item, or looking away; then sound394 -> sound312.
	await place(scene, -3690, -372, -PI/2)
	scene.draracle_local19 = 1
	if scene.draracle_bars.use_control(): return fail("Control79 used at local19 1")
	scene.draracle_local19 = 2
	scene.player.rotation.y = PI/2
	if scene.draracle_bars.use_control(): return fail("Control79 used while looking away")
	scene.player.rotation.y = -PI/2
	scene.camera.rotation.x = atan2(40.0 - (scene.camera.global_position.y), 65.0)
	scene.hand_item = "x"
	if scene.draracle_bars.use_control(): return fail("Control79 used with a held item")
	scene.hand_item = ""
	if not scene.draracle_bars.use_control(): return fail("Control79 empty-hand use refused at local19 2 (camera %s)" % scene.camera.global_position)
	if scene.draracle_local19 != 3 or scene.draracle_bars.voice_clip != 394 or not scene.draracle_bars.voice.playing: return fail("Control79 did not play sound394 / set local19 3")
	if scene.draracle_bars.use_control(): return fail("Control79 ran twice")
	scene.draracle_bars._voice_finished()
	if scene.draracle_bars.voice_clip != 312 or not scene.draracle_bars.voice.playing: return fail("Sound394 end did not play sound312")
	scene.draracle_bars._voice_finished()
	if scene.draracle_bars.voice_clip != 0: return fail("Sound312 end chained further")
	var after: Dictionary = scene.capture_exhibit_retry()
	if after.checkpoint.museum_draracle != {"local19": 3} or not Save.validate(after).is_empty(): return fail("Local19 3 save")
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	print("PASS museum draracle bars: control walk passes lowered bars; actual region1174 entry runs g1364 once (bars 71-74 -> -20, gate77 closes); raised bars block; mid-travel/legacy save; control79 394 -> 312 with refusals")
	quit()
