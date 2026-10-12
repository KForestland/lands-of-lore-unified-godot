extends SceneTree
const Save = preload("res://scripts/lol2/museum_save.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	assert(not scene.set_equipped_armor(Save.MAIL))
	assert(not scene.set_equipped_armor(Save.SWORD))
	scene.carried_collected = [Save.SWORD,Save.MAIL]
	scene.sword_transfer.collect()
	assert(scene.set_equipped_item(Save.SWORD))
	assert(scene.open_inventory())
	await process_frame
	await process_frame
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	assert(scene.inventory.detail_name.text == "Mail Shirt")
	for pressed in [true,false]:
		var click := InputEventMouseButton.new()
		click.position = scene.inventory.equip_button.get_global_rect().get_center()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		Input.flush_buffered_events()
	assert(scene.equipped_armor == Save.MAIL and scene.equipped_item == Save.SWORD)
	assert(scene.inventory.detail_name.text.ends_with("Equipped"))
	scene.inventory.equip_button.pressed.emit()
	assert(scene.equipped_armor == "" and scene.equipped_item == Save.SWORD)
	scene.inventory.equip_button.pressed.emit()
	scene.inventory.close()
	await process_frame
	await process_frame
	var path := "user://tests/armor_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(path).is_empty())
	var saved := Save.read_save(path)
	assert(saved.error.is_empty() and saved.state.checkpoint.equipped_armor == Save.MAIL)
	scene.set_equipped_armor("")
	assert(scene.quickload(path).is_empty() and scene.equipped_armor == Save.MAIL)
	var invalid: Dictionary = saved.state.duplicate(true)
	invalid.checkpoint.collected.erase(Save.MAIL)
	assert(not Save.validate(invalid).is_empty())
	scene.free()
	scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(scene)
	assert(scene.equipped_armor == Save.MAIL and scene.equipped_item == Save.SWORD)
	scene.interface_hud.set_cursor(true)
	scene.interface_hud.open_page("character")
	assert(scene.interface_hud.sheet_body.text.contains("Armor: Mail Shirt"))
	if "--capture-armor" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/bob/lol2_out/museum_sword_transfer_review_20260914/godot_armor.png")
	var legacy: Dictionary = saved.state.duplicate(true)
	legacy.checkpoint.erase("equipped_armor")
	assert(Save.write_save(path,legacy).is_empty())
	assert(scene.quickload(path).is_empty())
	assert(scene.equipped_armor == "" and scene.equipped_item == Save.SWORD)
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	DirAccess.remove_absolute(path)
	print("Armor passed: ownership, keyboard selection and actual Equip click, independent slots, unequip, save/revisit, legacy defaults")
	quit()
