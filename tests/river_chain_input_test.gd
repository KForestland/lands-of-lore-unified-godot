extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(300):
		await process_frame
		if is_instance_valid(scene.river_chains): break
	for i in range(5): await physics_frame
	assert(scene.river_chains.chains.size() == 24)
	var river = preload("res://scripts/lol2/river_region_query.gd").new()
	assert(river.regions.size() == 37)
	assert(not river.on_riverbed(Vector3(-65,-258,-17050),true))
	assert(not river.on_riverbed(Vector3(-65,-363,-17050),false))
	assert(river.region_at(Vector3(-65,-263,-18615)) == -1)
	scene.player.global_position = Vector3(-65,-258,-17050) + scene.native_translation
	scene.player.rotation = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var retreat := "--retreat" in OS.get_cmdline_user_args()
	var onward := "--toward-throne" in OS.get_cmdline_user_args()
	var second := 95 if onward else 94
	for id in [93,second]:
		if retreat and id == second:
			var back := InputEventKey.new()
			back.keycode = KEY_W if onward else KEY_S
			back.physical_keycode = back.keycode
			back.pressed = true
			Input.parse_input_event(back)
			await process_frame
			for i in range(115 if onward else 45): await physics_frame
			back = back.duplicate()
			back.pressed = false
			Input.parse_input_event(back)
			await process_frame
			for i in range(2): await physics_frame
			var native: Vector3 = scene.player.global_position-scene.native_translation
			assert((native.z < -17170 and native.z > -17230) if onward else (native.z > -17011 and native.z < -16950), "Retreat reaches neighboring intact section")
			assert(absf(native.y+258) < 1 and scene.player.is_on_floor())
		scene.camera.look_at(scene.river_chains.chains[id].target,Vector3.UP)
		for i in range(3): await physics_frame
		assert(scene.river_chains.target_chain() == id)
		if id == 93:
			scene.flying = true
			assert(not scene.river_chains.strike())
			scene.flying = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			assert(not scene.river_chains.strike())
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			assert(scene.river_chains.near_bridge())
			assert(scene.river_chains.status_text().begins_with("Cut two"))
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("/home/bob/lol2_out/chamber_route_20260913/chain_intact.png") == OK)
		var event := InputEventKey.new()
		event.keycode = KEY_E
		event.physical_keycode = KEY_E
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		await process_frame
		await physics_frame
		await physics_frame
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		assert(scene.river_deck.chain_rule.cut.has(id))
		if id == 93: assert(scene.river_deck.sections[58].body.collision_layer == 1)
	assert(scene.river_deck.sections[58].body.collision_layer == 0)
	for i in range(115): await physics_frame
	assert(not scene.river_deck.sections[58].mesh.visible)
	assert(scene.river_chains.chains[93].frame == 25)
	if retreat:
		assert(absf(scene.player.global_position.y-scene.native_translation.y+258) < 1)
		assert(scene.player.is_on_floor() and scene.resets == 0)
		assert(not scene.drowning.active and not scene.drowning.dead)
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("/home/bob/lol2_out/chamber_route_20260913/retreat.png") == OK)
	else:
		assert(scene.player.global_position.y-scene.native_translation.y < -300, "Player loses support over collapsed section")
		assert(river.on_riverbed(scene.player.global_position-scene.native_translation,scene.player.is_on_floor()))
	for id in [56,57,59,60,61]: assert(scene.river_deck.sections[id].body.collision_layer == 1)
	if onward:
		# Desktop mouse events must not steer the automated straight walk.
		scene.set_process_unhandled_input(false)
		scene.player.rotation = Vector3.ZERO
		scene.camera.rotation = Vector3.ZERO
		var forward := InputEventKey.new()
		forward.keycode = KEY_W
		forward.physical_keycode = KEY_W
		forward.pressed = true
		Input.parse_input_event(forward)
		await process_frame
		for i in range(1300):
			await physics_frame
			if scene.chamber_arrival_state == "playing": break
		forward = forward.duplicate()
		forward.pressed = false
		Input.parse_input_event(forward)
		print("Escape result ",scene.player.global_position-scene.native_translation," state=",scene.chamber_arrival_state," resets=",scene.resets)
		assert(scene.chamber_arrival_state == "playing" and scene.resets == 0)
		scene.video_overlay.review.close()
		await process_frame
		await process_frame
	print("Retreat mode=",retreat," reached throne=",onward)
	print("River chain input passed: aimed E cuts two distinct supports, first retains deck, second drops only its section and correct player support outcome")
	scene.free()
	quit()
