extends RefCounted
## Specialized player-input driver for the earned escape test. It edits no game state.
func run(test: Variant) -> bool:
	var scene: Node = test.scene
	test.look_toward(scene.crates.center_of(451))
	await test.physics_frame
	await test.tap(KEY_E)
	if scene.crates.state_of(451) != 1: return test.fail("earned E did not expose crystal451")
	# Same staged floor route as the placed shove probe; all movement now W/mouse.
	await test.f5()
	test.copy_file(test.DarkHalls.DEFAULT_PATH, test.OUT + "entry_escape_approach.json")
	var path: Array = load("res://tests/dark_halls_escape_earned_test.gd").PATH
	# Approach the north side in two clear legs before touching the selected crate.
	var start: Vector3 = scene.crates.center_of(451)
	var safe_z := maxf(scene.player.position.z,start.z+37.0)
	if not await test.walk_to(Vector2(scene.player.position.x,safe_z),6,900,"escape_get_north"): return false
	if not await test.walk_to(Vector2(start.x,safe_z),6,900,"escape_align"): return false
	print("ESCAPE aligned crate451 ",scene.crates.center_of(451)," player ",scene.player.position)
	var points: Array = []
	for point in path: points.append([point.x,point.y])
	var last_dir := Vector3.ZERO
	for k in points.size():
		var goal := Vector2(points[k][0],points[k][1])
		var reached := false
		for i in 900:
			test.trace_health("shove451")
			if test.health() <= 0: return test.fail("fell shoving451")
			if not test.threat(95).is_empty():
				test.set_key(KEY_W,false)
				if not await test.fight(140,"shove451"): return false
			var now: Vector3 = scene.crates.center_of(451)
			var remain := goal - Vector2(now.x,now.z)
			if remain.length() < 16:
				reached = true
				break
			last_dir = Vector3(remain.x,0,remain.y).normalized()
			var stand := now - last_dir * 26.0
			stand.y = scene.player.position.y
			var target := stand
			if Vector2(stand.x-scene.player.position.x,stand.z-scene.player.position.z).length() < 2: target += last_dir * 40
			test.look_toward(target,false)
			test.set_key(KEY_SHIFT,false)
			test.set_key(KEY_W,true)
			await test.physics_frame
		test.set_key(KEY_W,false)
		if not reached: return test.fail("crate451 shove stuck at waypoint%d crate%s player%s" % [k,scene.crates.center_of(451),scene.player.position])
	var retreat: Vector3 = scene.player.position - last_dir * 110
	if not await test.walk_to(Vector2(retreat.x,retreat.z),8,60*30,"escape_retreat"): return false
	if not await test.spark_crate(451): return false
	if not scene.exits_open() or scene.windows.done(): return test.fail("blast route not independent of window counter")
	if not await test.saved_roundtrip(func(): return test.scene.exits_open()): return false
	scene = test.scene
	await test.ensure_captured()
	return await test.jump_to_window(scene.windows.exit_center(),scene.windows._inward(scene.windows.by_control[246]),true)
