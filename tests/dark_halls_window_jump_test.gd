extends "res://tests/dark_halls_objects_earned_test.gd"
## Placed geometry probe, not an earned route. Input only after the explicitly placed stand.
func run() -> void:
	phase = "window_jump_probe"
	change_scene_to_file(HALLS)
	scene = await wait_scene(HALLS)
	if scene == null: return fail("scene missing")
	scene.creatures.set_physics_process(false)
	for body in scene.creatures.bodies.values(): body.collision_layer = 0
	var window: Vector3 = scene.windows.exit_center()
	var row: Dictionary = scene.windows.by_control[246]
	var inward: Vector3 = scene.windows._inward(row)
	scene.player.position = window + inward * 190.0
	scene.player.position.y = 782.0
	scene.player.velocity = Vector3.ZERO
	await ensure_captured()
	for i in 20: await physics_frame
	look_toward(window - inward * 120.0, false)
	# Closed pane must block an actual jumping player.
	if await jump_to_window(window, inward, false): return fail("closed window let player through")
	if current_scene != scene: return fail("closed window changed area")
	var earlier: Dictionary = snapshot()
	scene.quest_state.dark_halls_crates = {"version":1,"crates":{},"door":0,"blast_exit":1,"exit_group":scene.crates.exit_group_fields("c59085050a00")}
	scene.windows.break_exit()
	await f5()
	if not scene.apply_save(earlier).is_empty() or scene.windows.exit_body.collision_layer & 256 == 0: return fail("earlier save did not reseal pane")
	await tap(KEY_F9)
	for i in 3: await physics_frame
	if scene.windows.exit_body.collision_layer != 0: return fail("F9 did not restore broken pane")
	await ensure_captured()
	if not await jump_to_window(window, inward, true): return
	print("PASS dark_halls_window_jump: closed pane blocks, earlier save/F9 restore, W+Space crosses actual sill/hole to native Jungle entry6")
	quit(0)

func jump_to_window(window: Vector3, inward: Vector3, must_exit: bool) -> bool:
	var goal := window - inward * 120.0
	look_toward(goal, false)
	set_key(KEY_SHIFT, false)
	set_key(KEY_W, true)
	var jumped := 0
	for i in 750:
		if not is_instance_valid(scene) or current_scene != scene:
			release_keys()
			var destination := await wait_scene(JUNGLE)
			if destination == null: return fail("no Jungle after window")
			var target: Array = load("res://scripts/lol2/dark_halls_route.gd").catalog().routes.dark_halls[0].arrival
			if destination.player.position.distance_to(Vector3(target[0],target[1],target[2])) > 12: return fail("wrong Jungle arrival")
			return true
		var d: float = Vector2(scene.player.position.x-window.x,scene.player.position.z-window.z).length()
		# Leap near the 10-unit curb; retry from the sill if the header stops the first arc.
		if scene.player.is_on_floor() and d < 155 and i % 35 == 0:
			await tap(KEY_SPACE)
			jumped += 1
		await physics_frame
	release_keys()
	if must_exit: return fail("window jump stopped at %s, jumps %s" % [scene.player.position,jumped])
	return false

func snapshot() -> Dictionary:
	var path := "user://tests/bh09_snapshot.json"
	var error: String = scene.quicksave(path)
	if not error.is_empty():
		push_error(error)
		return {}
	return JSON.parse_string(FileAccess.get_file_as_string(path))
