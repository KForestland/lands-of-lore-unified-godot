extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func museum() -> Node3D:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	return scene
func _run() -> void:
	var scene := museum()
	assert(not scene.set_equipped_item(scene.SWORD_ITEM_ID))
	assert(not scene.set_equipped_item("unidentified"))
	scene.carried_collected = [scene.SWORD_ITEM_ID, "draracle/prop/1108/sample"]
	assert(scene.open_inventory())
	await process_frame
	await process_frame
	var panel = scene.inventory
	assert(not panel.equip_button.disabled)
	# Dispatch a real GUI click to equip the selected longsword.
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = panel.equip_button.get_global_rect().get_center()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		Input.flush_buffered_events()
	assert(scene.equipped_item == scene.SWORD_ITEM_ID)
	assert(panel.equip_button.text == "Unequip" and panel.detail_name.text.ends_with("Equipped"))
	assert(scene.interface_hud.weapon_icon.visible)
	panel.select_item(1)
	assert(panel.equip_button.disabled)
	panel.toggle_equipment()
	assert(scene.equipped_item == scene.SWORD_ITEM_ID)
	panel.select_item(0)
	panel.equip_button.pressed.emit()
	assert(scene.equipped_item == "" and not scene.interface_hud.weapon_icon.visible)
	panel.equip_button.pressed.emit()
	assert(scene.carried_collected.size() == 2)
	if "--capture-equipment" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/bob/lol2_out/museum_sword_transfer_review_20260914/godot_equipment.png")
	scene.free()
	assert(not paused)
	scene = museum()
	assert(scene.equipped_item == scene.SWORD_ITEM_ID and scene.interface_hud.weapon_icon.visible)
	assert(scene.sword_transfer.collected)
	scene.interface_hud.set_cursor(true)
	scene.interface_hud.open_page("character")
	assert(scene.interface_hud.sheet_body.text.contains("Weapon: Fine Longsword"))
	assert(scene.interface_hud.weapon_button.tooltip_text.begins_with("Fine Longsword"))
	scene.carried_collected.reverse()
	await process_frame
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = scene.interface_hud.weapon_button.get_global_rect().get_center()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		Input.flush_buffered_events()
	assert(paused and is_instance_valid(scene.inventory))
	assert(not scene.interface_hud.sheet.visible)
	assert(scene.inventory.selected_index == 1)
	assert(scene.inventory.detail_name.text == "Fine Longsword · Equipped")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	scene.inventory.close()
	await process_frame
	await process_frame
	assert(not paused and scene.interface_hud.cursor_active)
	scene.interface_hud.set_cursor(false)
	assert(scene.interface_hud.weapon_button.disabled)
	scene.free()
	var saved: Dictionary = get_meta("lol2_museum_checkpoint")
	saved.collected = []
	set_meta("lol2_museum_checkpoint", saved)
	scene = museum()
	assert(scene.equipped_item == "" and not scene.interface_hud.weapon_icon.visible)
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	print("Equipment passed: ownership, actual Equip click, unknown rejection, unequip, HUD, revisit, invalid saved ownership")
	quit()
