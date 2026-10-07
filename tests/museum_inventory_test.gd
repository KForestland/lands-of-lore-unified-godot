extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.carried_collected = [scene.SWORD_ITEM_ID,"draracle/prop/1108/sample",scene.SWORD_ITEM_ID]
	scene.sword_transfer.restart()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var original_mouse := Input.mouse_mode
	assert(scene.open_inventory() and paused)
	assert(not scene.open_inventory())
	assert(scene.inventory.item_list.item_count == 2)
	assert(scene.inventory.item_list.get_item_text(0) == "Fine Longsword")
	assert(scene.inventory.detail_name.text == "Fine Longsword")
	assert(scene.inventory.detail_icon.texture != null)
	var selection_key := InputEventKey.new()
	selection_key.keycode = KEY_DOWN
	selection_key.pressed = true
	Input.parse_input_event(selection_key)
	Input.flush_buffered_events()
	assert(scene.inventory.detail_name.text == "Cavern find (unidentified)")
	assert(scene.inventory.detail_icon.texture == null)
	assert(scene.inventory.detail_text.text.contains("identity is unknown"))
	var elapsed: float = scene.sword_transfer.elapsed
	await create_timer(0.1).timeout
	assert(scene.sword_transfer.elapsed == elapsed)
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	scene.inventory._input(event)
	await scene.inventory.tree_exited
	await process_frame
	assert(not paused and Input.mouse_mode == original_mouse)
	assert(scene.carried_collected.size() == 3)
	assert(scene.open_inventory())
	scene.inventory.close()
	await scene.inventory.tree_exited
	await process_frame
	assert(not paused)
	scene.carried_collected = []
	assert(scene.open_inventory() and scene.inventory.item_list.item_count == 0)
	assert(scene.inventory.detail_name.text == "No items collected.")
	# Exiting with inventory open must not leave the next scene paused.
	scene.free()
	assert(not paused)
	remove_meta("lol2_museum_checkpoint")
	print("Museum inventory passed: item names, deduplicated display, pause, Esc, reopen, empty view and scene exit")
	quit()
