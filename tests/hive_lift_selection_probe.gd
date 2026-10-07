extends "res://tests/hive_lift_wax_walk_test.gd"
const RuneItems = preload("res://scripts/lol2/hive_rune_items.gd")
func _initialize() -> void:
	extended = true
	run.call_deferred()
func aim(point: Vector3) -> void:
	var direction: Vector3 = point-scene.camera.global_position
	scene.player.rotation.y = atan2(-direction.x,-direction.z)
	scene.camera.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	if cave_chain: current_scene = scene
	await process_frame
	await physics_frame
	root.grab_focus()
	for frame in range(3): await process_frame
	scene.set_development_mode(false)
	var input_path := chain_save("user://tests/act1_wax_upper_return.json")
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chain_proof("res://docs/hive-wax-return-checks.json")))
	if not proof.get("earned_checkpoint",false) or FileAccess.get_sha256(input_path) != proof.get("output_checkpoint_sha256",""):
		fail("Wax checkpoint does not match the earned-route proof")
		return
	for attempt in range(5):
		if not scene.quickload(input_path).is_empty():
			fail("Earned wax checkpoint unavailable")
			return
		scene.set_physics_process(false)
		scene.get_node("Warriors").set_process(cave_chain)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if not "hive:item0:Wax" in scene.carried_inventory.collected:
			fail("Earned checkpoint lacks wax")
			return
		for tick in range(10):
			await physics_frame
			scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
		if not await move_to(Vector2(-2355,-7614)): return
		if not scene.request_jump():
			fail("Cannot jump onto upper platform")
			return
		if not await move_to(Vector2(-2510,-7614),true): return
		if not await move_to(Vector2(-2564.5,-7614.5)): return
		for stop in range(1,8):
			aim(scene.elevator.aim_point(125))
			if not scene.elevator.interact():
				var point: Vector3 = scene.elevator.aim_point(125)
				var offset: Vector3 = point-scene.camera.global_position
				var query := PhysicsRayQueryParameters3D.create(scene.camera.global_position,point,1,[scene.player.get_rid()])
				query.hit_from_inside = true
				print("Lift selection failure: stop=",stop," position=",scene.player.position," camera=",scene.camera.global_position," form=",scene.player_form," mouse=",Input.mouse_mode," cursor=",scene.interface_hud.cursor_active," health=",scene.get_node("Warriors").health," distance=",offset.length()," aim_dot=",(-scene.camera.global_basis.z).dot(offset.normalized())," ray=",scene.get_world_3d().direct_space_state.intersect_ray(query))
				fail("Cannot select rune descent stop")
				return
			for tick in range(1200):
				await physics_frame
				var delta: float = scene.player.get_physics_process_delta_time()
				scene.move_grounded(Vector3.ZERO,delta)
				tick_curse(delta)
				if is_equal_approx(scene.elevator.checkpoint.height,scene.elevator.State.STOPS[stop]): break
			if not is_equal_approx(scene.elevator.checkpoint.height,scene.elevator.State.STOPS[stop]):
				fail("Rune descent did not reach stop")
				return
		print("PASS lift interaction probe repetition ",attempt+1,"; seven actual stops")
	await RenderingServer.frame_post_draw
	scene.queue_free()
	await process_frame
	await process_frame
	quit()
