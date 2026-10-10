extends SceneTree
## Actual Cave host, grounded movement (move_and_slide with the host walk step) over a source region route:
## shaft rim (region398) -> prop83 (region1040); unarmed strike refused; armed left-click strike (kind9 g108) starts
## sound 956; at its end g146/g264 run: prop83 state1, wall regions 1029..1033 opened (collision ray now clear), the
## shaft floor rises; mid-lift save/load; walk back, step into the raised shaft, take the Mana foil (control75 rode the
## floor), walk out onto the rim; riding the lift up from the shaft bottom and walking out; save validation negatives.
const State = preload("res://scripts/lol2/cave_prop83_lift_state.gd")
const Foil = preload("res://scripts/lol2/cave_stone_manafoil.gd")
const ROUTE := [[170.8, -10720.5], [150.5, -10709.0], [143.8, -10702.2], [137.0, -10695.5], [132.8, -10688.0], [128.5, -10680.5], [125.0, -10674.8], [121.5, -10669.0], [121.8, -10656.2], [122.0, -10643.5], [129.2, -10635.8], [136.5, -10628.0], [149.5, -10627.0], [162.5, -10626.0], [176.8, -10623.2], [191.0, -10620.5], [197.2, -10622.5], [203.5, -10624.5], [215.8, -10638.8], [228.0, -10653.0], [233.8, -10659.2], [239.5, -10654.0], [263.5, -10647.2], [287.5, -10640.5], [300.8, -10633.5], [314.0, -10626.5], [327.0, -10618.8], [340.0, -10611.0], [365.5, -10598.0], [391.0, -10585.0], [403.2, -10572.5], [415.5, -10560.0], [449.0, -10545.8], [482.5, -10531.5], [525.0, -10510.5], [535.0, -10545.5], [535.8, -10577.0], [536.5, -10608.5], [533.1, -10642.0], [529.8, -10675.5], [528.4, -10690.3], [527.1, -10705.0], [524.5, -10738.5], [522.0, -10772.0], [519.2, -10804.8], [516.5, -10837.5], [509.0, -10860.2], [501.5, -10883.0], [491.0, -10898.8], [480.5, -10914.5], [466.8, -10927.5], [453.0, -10940.5], [439.2, -10949.5], [425.5, -10958.5], [405.0, -10964.5], [384.5, -10970.5], [358.7, -10978.7], [369.0, -11013.4], [369.5, -11015.7], [370.0, -11018.0]]
const RIM := [170.75, -285.0, -10720.5]
const SHAFT := [200.5, -1000.0, -10690.0]
var cave
var lift
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); quit(1)
func host_point(x: float, y: float, z: float) -> Vector3: return Vector3(x, y, z) + cave.native_translation
var jumps := 0
## One host walk step per frame (WALK speed, gravity 128/s, jump = the host's Space jump).
func step(dir: Vector3, frames: int, jump := false) -> void:
	for i in frames:
		cave.player.velocity.x = dir.x * cave.WALK_SPEED
		cave.player.velocity.z = dir.z * cave.WALK_SPEED
		cave.player.velocity.y = cave.JUMP_SPEED if jump and cave.player.is_on_floor() else (0.0 if cave.player.is_on_floor() else cave.player.velocity.y - 128.0 / 60.0)
		cave.player.move_and_slide()
		await physics_frame
## Walks through native xz waypoints; fails if a waypoint is not reached within its frame budget.
func walk(points: Array) -> bool:
	for wp in points:
		var target := host_point(float(wp[0]), 0.0, float(wp[1]))
		var frames := 0
		var best := INF; var stalled := 0
		while true:
			var d: Vector3 = target - cave.player.global_position; d.y = 0
			if d.length() < 5.0: break
			frames += 1
			if frames > 240:
				fail("Stuck walking to %s at %s" % [wp, cave.player.global_position - cave.native_translation]); return false
			if d.length() < best - 0.5: best = d.length(); stalled = 0
			else: stalled += 1
			# A player hops over small source floor lips (Space); counted and reported.
			var hop := stalled > 12
			if hop: stalled = 0; jumps += 1
			await step(d.normalized(), 1, hop)
	return true
func feet_native() -> float: return lift._player_feet() - cave.native_translation.y
## Native height of the surface straight below the player (ray), the floor actually stood on.
func floor_native() -> float:
	var p: Vector3 = cave.player.global_position
	var ray := PhysicsRayQueryParameters3D.create(p, p - Vector3(0, 2000, 0), 1, [cave.player.get_rid()])
	var hit: Dictionary = cave.get_world_3d().direct_space_state.intersect_ray(ray)
	return (hit.position.y - cave.native_translation.y) if not hit.is_empty() else -INF
## Standing on a surface at `height` (ray, within 1.5) after settling: feet 0..8 above it (capsule margin; the
## capsule may rest on a floor edge, where is_on_floor() can read false while the player is stationary).
func standing_on(height: float) -> bool:
	var gap := feet_native() - floor_native()
	return absf(floor_native() - height) < 1.5 and gap > -0.5 and gap < 8.0
func settle() -> void: await step(Vector3.ZERO, 60)
func run() -> void:
	var path := "user://tests/cave_prop83_lift.json"
	cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene = cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready: break
	cave.set_physics_process(false); cave.flying = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	lift = cave.prop83_lift
	if lift == null or lift.checkpoint() != State.initial(): return fail("Lift owner missing/not initial")
	var space: PhysicsDirectSpaceState3D = cave.get_world_3d().direct_space_state
	var wall_ray := PhysicsRayQueryParameters3D.create(host_point(336.5, -120.0, -11107.0), host_point(322.25, -120.0, -11149.5), 1, [cave.player.get_rid()])
	if space.intersect_ray(wall_ray).is_empty(): return fail("Wall block 1029 not solid before the chain")
	# Grounded approach from the shaft rim to prop83 along the source region route.
	cave.player.global_position = host_point(RIM[0], RIM[1] + 40.0, RIM[2]); cave.player.velocity = Vector3.ZERO
	await settle()
	if not standing_on(RIM[1]): return fail("Not standing on the rim: feet %f floor %f" % [feet_native(), floor_native()])
	if not await walk(ROUTE): return
	if not standing_on(-192.0): return fail("Did not arrive on prop83's floor: feet %f floor %f" % [feet_native(), floor_native()])
	# Unarmed strike refused; armed left-click strike (kind9 g108).
	var weapon: String = preload("res://scripts/lol2/cave_stalagmite.gd").item_id(144, 1)
	cave.stalagmites.collected.append(weapon)
	cave.camera.look_at(lift.body.global_position); await physics_frame
	cave.equipped_item = ""
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
	cave._unhandled_input(click)
	if float(lift.state.sound) != 0.0: return fail("Unarmed strike accepted")
	cave.equipped_item = weapon
	var pre_path := "user://tests/cave_prop83_lift_pre.json"
	if not cave._quicksave(pre_path).is_empty(): return fail("Pre-chain save failed")
	cave.set_physics_process(false); cave.flying = false
	cave._unhandled_input(click)
	if not (float(lift.state.sound) > 0.0 and int(lift.state.state) == 0 and lift.sound.playing): return fail("Armed strike did not start sound 956: %s" % [lift.state])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/cave_prop83_strike.png")
	# Mid-sound save/load resumes the clip at (length - remaining).
	lift._physics_process(0.2)
	var sound_left: float = float(lift.state.sound)
	var sound_path := "user://tests/cave_prop83_lift_sound.json"
	if not cave._quicksave(sound_path).is_empty(): return fail("Mid-sound save failed")
	lift._physics_process(0.1)
	if not cave._quickload(sound_path).is_empty() or absf(float(lift.state.sound) - sound_left) > 1e-6 or not lift.sound.playing: return fail("Mid-sound reload: %s playing %s" % [lift.state, lift.sound.playing])
	cave.set_physics_process(false); cave.flying = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if absf(lift.sound.get_playback_position() - (lift.sound_seconds - sound_left)) > 0.06: return fail("Clip not resumed at its remainder: %f" % lift.sound.get_playback_position())
	# Shared world gate mid-sound: inventory open, then a released cursor, freeze the chain and pause the clip.
	var ikey := InputEventKey.new(); ikey.keycode = KEY_I; ikey.pressed = true
	cave._unhandled_input(ikey); await process_frame
	if not is_instance_valid(cave.inventory): return fail("Inventory did not open")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 20: lift._physics_process(0.05)
	if float(lift.state.sound) != sound_left or int(lift.state.state) != 0 or not lift.sound.stream_paused: return fail("Inventory did not pause the chain: %s paused %s" % [lift.state, lift.sound.stream_paused])
	cave.inventory.queue_free(); await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Closing the inventory recaptures the mouse, so the owner's own physics may have run one live frame.
	sound_left = float(lift.state.sound)
	for i in 20: lift._physics_process(0.05)
	if float(lift.state.sound) != sound_left: return fail("Released cursor did not pause the chain")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	lift._physics_process(0.01)
	if absf(float(lift.state.sound) - (sound_left - 0.01)) > 1e-9 or lift.sound.stream_paused: return fail("Resume jumped: %s" % [lift.state])
	for i in 20: lift._physics_process(0.05)
	if not (int(lift.state.state) == 1 and bool(lift.state.opened) and int(lift.state.local25) == 0 and lift.opened_applied): return fail("Chain did not complete: %s" % [lift.state])
	await physics_frame
	if not space.intersect_ray(wall_ray).is_empty(): return fail("Wall block still solid after opening: %s" % [space.intersect_ray(wall_ray)])
	if lift.prop_instance != null and lift.prop_instance.visible: return fail("prop83 still visible after property16")
	# Mid-lift save/load.
	for i in 400: lift._physics_process(0.05)
	var mid: float = float(lift.state.shaft)
	if not (mid > -1000.0 and mid < -290.0): return fail("Not mid-lift: %f" % mid)
	# Mid-lift cursor pause freezes the floor; resume continues without a jump.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 40: lift._physics_process(0.05)
	if float(lift.state.shaft) != mid: return fail("Paused lift moved")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	lift._physics_process(0.05)
	if absf(float(lift.state.shaft) - (mid + 0.05 * State.SPEED * State.UNITS_PER_SPEED)) > 1e-6: return fail("Lift resume jumped: %f" % float(lift.state.shaft))
	mid = float(lift.state.shaft)
	if not cave._quicksave(path).is_empty(): return fail("Mid-lift save failed")
	for i in 100: lift._physics_process(0.05)
	if not cave._quickload(path).is_empty() or absf(float(lift.state.shaft) - mid) > 0.001: return fail("Mid-lift reload: %f vs %f" % [float(lift.state.shaft), mid])
	cave.set_physics_process(false); cave.flying = false
	# Rewind: a pre-chain save restores the solid wall block and the unlifted shaft; the mid-lift save reopens.
	if not cave._quickload(pre_path).is_empty() or lift.checkpoint() != State.initial() or lift.opened_applied: return fail("Pre-chain reload: %s" % [lift.state])
	await physics_frame
	if space.intersect_ray(wall_ray).is_empty(): return fail("Wall block not restored on rewind")
	if lift.prop_instance != null and not lift.prop_instance.visible: return fail("prop83 not restored on rewind")
	if not cave._quickload(path).is_empty() or absf(float(lift.state.shaft) - mid) > 0.001 or not lift.opened_applied: return fail("Reopen reload failed")
	await physics_frame
	if not space.intersect_ray(wall_ray).is_empty(): return fail("Wall block solid after reopening")
	cave.set_physics_process(false); cave.flying = false
	for i in 1200: lift._physics_process(0.05)
	if float(lift.state.shaft) != State.SHAFT_TOP: return fail("Lift did not finish: %f" % float(lift.state.shaft))
	# Walk back to the rim, step into the raised shaft, take the Mana foil, walk out.
	cave.player.global_position = host_point(370.0, -192.0 + 40.0, -11018.0); cave.player.velocity = Vector3.ZERO
	await settle()
	var back := ROUTE.duplicate(); back.reverse()
	if not await walk(back): return
	if not await walk([[SHAFT[0], SHAFT[2]]]): return
	await settle()
	if not standing_on(State.SHAFT_TOP): return fail("Not standing on the raised shaft floor: feet %f floor %f" % [feet_native(), floor_native()])
	var foil_owner = cave.stone_manafoil
	cave.camera.look_at(foil_owner.aim_point(Foil.FOIL)); await physics_frame
	if foil_owner.target() != Foil.FOIL:
		for k in 8:
			var d := Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0))
			await step(d, 6); cave.camera.rotation = Vector3.ZERO; cave.player.rotation = Vector3.ZERO; await physics_frame
			cave.camera.look_at(foil_owner.aim_point(Foil.FOIL)); await physics_frame
			if foil_owner.target() == Foil.FOIL: break
	if foil_owner.target() != Foil.FOIL: return fail("Mana foil not targetable on the raised floor")
	var e := InputEventKey.new(); e.keycode = KEY_E; e.pressed = true
	cave._unhandled_input(e); cave._update_interaction()
	if not Foil.FOIL in cave.carried_items(): return fail("Mana foil not taken")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/cave_prop83_shaft_raised.png")
	if not await walk([[RIM[0], RIM[2]]]): return
	await settle()
	if not standing_on(RIM[1]): return fail("Grounded escape to the rim failed: feet %f floor %f" % [feet_native(), floor_native()])
	# Riding the lift: from the shaft bottom (chain just completed) to the top, then out.
	var riding := State.initial(); riding.state = 1; riding.opened = true
	if not lift.restore(riding).is_empty(): return fail("Riding state rejected")
	cave.player.global_position = host_point(SHAFT[0], SHAFT[1] + 40.0, SHAFT[2]); cave.player.velocity = Vector3.ZERO
	await settle()
	# The owner's own physics keeps lifting during the settle frames: the player stands on the current shaft floor.
	if not standing_on(float(lift.state.shaft)) or float(lift.state.shaft) > -900.0: return fail("Not on the low shaft floor: feet %f shaft %f" % [feet_native(), float(lift.state.shaft)])
	for i in 1200:
		lift._physics_process(0.05)
		if i % 20 == 0: await step(Vector3.ZERO, 1)
	await settle()
	if not standing_on(State.SHAFT_TOP): return fail("Lift did not carry the player: feet %f floor %f" % [feet_native(), floor_native()])
	if not await walk([[RIM[0], RIM[2]]]): return
	await settle()
	if not standing_on(RIM[1]): return fail("Ride escape to the rim failed: feet %f floor %f" % [feet_native(), floor_native()])
	# Save validation.
	var bad: Dictionary = cave._save_state(); bad.prop83_lift = State.initial(); bad.prop83_lift.shaft = -500.0
	if cave.WalkthroughSave.validate(bad, cave._checkpoint_count()).is_empty(): return fail("Lift before the chain accepted")
	bad = cave._save_state(); bad.prop83_lift = State.initial(); bad.prop83_lift.state = 1
	if cave.WalkthroughSave.validate(bad, cave._checkpoint_count()).is_empty(): return fail("Unopened state1 accepted")
	if not cave.WalkthroughSave.validate(cave._save_state(), cave._checkpoint_count()).is_empty(): return fail("Valid lift save rejected")
	print("route hops: ", jumps)
	print("PASS cave_prop83_lift_live: grounded rim->prop83 route, unarmed refused, armed strike -> sound956 -> g146/g264 (state1, wall opened, prop83 hidden), mid-lift save/load, walk back, raised shaft floor, Mana foil taken (box rode the floor), grounded escape; riding the lift up and out; save negatives.")
	quit()
