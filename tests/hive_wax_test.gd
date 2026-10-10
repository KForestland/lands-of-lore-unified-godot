extends SceneTree
const Wax = preload("res://scripts/lol2/hive_wax.gd")
func _initialize() -> void: _run.call_deferred()
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func aim(scene: Node3D, point: Vector3) -> void:
	var direction: Vector3 = point-scene.camera.global_position
	scene.player.rotation.y = atan2(-direction.x,-direction.z)
	scene.camera.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
func walk(scene: Node3D, target: Vector3) -> void:
	for frame in range(240):
		var delta: Vector3 = target-scene.player.position
		delta.y = 0
		if delta.length() < 3.0: return
		scene.player.velocity = delta.normalized()*55.0 + Vector3(0,-15,0)
		scene.player.move_and_slide()
		await physics_frame
	assert(false,"Wax approach blocked: " + str(scene.player.position) + " -> " + str(target))
func _run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(false)
	var wax = scene.wax
	assert(wax.sprite.position == Vector3(-3716,-951,-6949))
	assert(not wax.collected and not wax.target())
	# Supplied approach/form fixture; continuous arrival and curse admission remain open.
	scene.player.position = Vector3(-3839.75,-919,-7015.25)
	var fixture: Dictionary = scene.area_handoff()
	fixture.inventory.player_form = 2
	fixture.inventory.erase("curse")
	assert(scene.apply_area_handoff(fixture).is_empty())
	scene.set_physics_process(false)
	for point in [Vector3(-3813.25,-919,-6990.5),Vector3(-3799,-919,-6974.75),Vector3(-3782.5,-919,-6957),Vector3(-3768,-919,-6948.25),Vector3(-3750,-919,-6945.5)]:
		await walk(scene,point)
	assert(not scene.FormBody.apply(scene.player,scene.camera,0,true))
	aim(scene,wax.aim_point())
	await physics_frame
	print("Wax fixture camera ",scene.camera.global_position," target ",wax.aim_point()," admitted ",wax.target())
	assert(wax.target())
	scene.interface_hud._process(0.0)
	assert(scene.interface_hud.hint.text == "E — Take wax")
	scene.interface_hud.set_cursor(true)
	assert(not wax.collect())
	scene.interface_hud.set_cursor(false)
	scene.player.rotation.y += PI
	assert(not wax.collect())
	aim(scene,wax.aim_point())
	var before: Dictionary = scene.area_handoff()
	var path := "user://tests/hive_wax_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(path).is_empty())
	key(KEY_E)
	assert(wax.collected and not wax.sprite.visible and Wax.ITEM in scene.carried_inventory.collected)
	assert(not wax.collect())
	assert(scene.open_inventory())
	assert(scene.inventory.item_list.get_item_text(0) == "Wax")
	scene.inventory.close()
	await process_frame
	await process_frame
	var collected: Dictionary = scene.area_handoff()
	assert(collected.quests.hive_wax_collected)
	assert(scene.quicksave(path+".after").is_empty())
	assert(scene.quickload(path).is_empty())
	assert(not wax.collected and wax.sprite.visible and Wax.ITEM not in scene.carried_inventory.collected)
	assert(scene.quickload(path+".after").is_empty())
	assert(wax.collected and not wax.sprite.visible and Wax.ITEM in scene.carried_inventory.collected)
	var bad: Dictionary = collected.duplicate(true)
	bad.quests.hive_wax_collected = 1
	assert(not scene.apply_area_handoff(bad).is_empty())
	assert(scene.area_handoff() == collected)
	# Once removed from inventory for a later quest, the world pickup stays gone.
	var with_wax: Dictionary = collected.duplicate(true)
	collected.inventory.collected.erase(Wax.ITEM)
	assert(scene.apply_area_handoff(collected).is_empty() and wax.collected)
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	await process_frame
	assert(jungle.apply_area_handoff(with_wax).is_empty())
	assert(Wax.ITEM in jungle.area_handoff().inventory.collected)
	assert(jungle.apply_area_handoff(collected).is_empty())
	var returned: Dictionary = jungle.area_handoff()
	assert(returned.quests.hive_wax_collected)
	assert(scene.apply_area_handoff(returned).is_empty() and wax.collected)
	jungle.free()
	# Older quest banks migrate with no pickup removed.
	before.quests.erase("hive_wax_collected")
	assert(scene.apply_area_handoff(before).is_empty() and not wax.collected)
	if "--capture-wax" in OS.get_cmdline_user_args():
		scene.player.position = Vector3(-3750,-919,-6945.5)
		aim(scene,wax.aim_point())
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/hive_wax.png")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path+".after")
	scene.free()
	print("PASS: source wax pickup, aim/overlay/duplicate guards, inventory, disk rollback, consumed-item persistence and Jungle carry")
	quit()
