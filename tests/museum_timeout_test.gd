extends SceneTree
func _initialize(): run.call_deferred()
func run():
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.hourglass.set_process(false)
	scene.player.position = Vector3(1332,32,-590)
	scene.player.rotation = Vector3.ZERO
	scene.camera.look_at(Vector3(1332,41,-663))
	scene.carried_collected.append(scene.SWORD_ITEM_ID)
	scene.sword_transfer.collect()
	scene.set_equipped_item(scene.SWORD_ITEM_ID)
	scene.gallery.move_painting()
	scene.gallery.pull_lever()
	scene.gallery._physics_process(1.2)
	await physics_frame
	assert(scene.strike_hourglass())
	var original_pose: Vector3 = scene.player.position
	scene.hourglass.restore_checkpoint({"activated":true,"stage":3,"elapsed":5,"wait":0,"final_wait":0.1})
	scene.hourglass._process(0.09)
	assert(not scene.hourglass.failed)
	scene.hourglass._process(0.02)
	assert(scene.hourglass.failed and not scene.hourglass.finish_escape())
	for i in range(3): await process_frame
	assert(paused and is_instance_valid(scene.failure_overlay))
	assert(not scene.strike_escape_wall() and not scene.quicksave("user://tests/must_not_write.json").is_empty())
	var overlay = scene.failure_overlay
	overlay.save_path = "user://tests/missing_timeout_%d.json" % OS.get_process_id()
	overlay.load_quicksave()
	assert(paused and not overlay.status.text.is_empty())
	overlay.retry()
	await process_frame
	assert(not paused and not scene.hourglass.activated and not scene.hourglass.failed)
	assert(scene.player.position == original_pose and scene.escape_wall.stage == 0 and scene.gallery.gate_open)
	assert(scene.equipped_item == scene.SWORD_ITEM_ID)
	# Reloaded active saves get a safe exhibit retry without needing a nested save.
	assert(scene.strike_hourglass())
	var state: Dictionary = scene.capture_exhibit_retry()
	state.checkpoint.hourglass = {"activated":true,"stage":3,"elapsed":5,"wait":0,"final_wait":0.1}
	scene.apply_save(state)
	assert(scene.exhibit_retry.player.position == [1332,32,-590])
	scene.hourglass._process(0.2)
	for i in range(3): await process_frame
	assert(paused)
	scene.failure_overlay.retry()
	await process_frame
	assert(not paused and not scene.hourglass.activated and scene.gallery.gate_open)
	print("Museum timeout passed: deadline, failure once, pause, missing-load safety, retry with equipment and loaded-save recovery")
	quit()
