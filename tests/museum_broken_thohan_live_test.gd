extends SceneTree
const Broken = preload("res://scripts/lol2/museum_broken_thohan.gd")
const Magic = preload("res://scripts/lol2/magic_shop_state.gd")
func _initialize(): run.call_deferred()
func finish(shop):
	for i in 1500:
		if not Magic.active(shop.state()): return
		shop.advance(0.1)
	assert(false)
func run():
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum)
	current_scene = museum
	await process_frame
	museum.set_physics_process(false)
	museum.sword_transfer.set_process(false)
	var control = museum.broken_thohan
	var target: Vector3 = control.aim_point()
	museum.player.position = target+Vector3(0,-museum.camera.position.y,60)
	museum.camera.look_at(target)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await physics_frame
	assert(museum.broken_case.face_count == 46)
	assert(control.sword.position == museum.broken_case.sword_anchor())
	assert(control.interaction_hint() == "E — Take Broken Thohan")
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tmp/regressions/museum_complete_case_20260928")
	assert(root.get_texture().get_image().save_png("res://tmp/regressions/museum_complete_case_20260928/exhibit.png") == OK)
	var event = InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	museum._unhandled_input(event)
	assert(Broken.ITEM in museum.carried_collected and museum.hand_item == Broken.ITEM and not control.sword.visible)
	var path = "user://tests/museum_broken_sword.json"
	var save_error: String = museum.quicksave(path)
	if not save_error.is_empty():
		push_error(save_error)
		quit(1)
		return
	assert(museum.open_inventory())
	await process_frame
	museum.inventory.select_item(museum.carried_collected.find(Broken.ITEM))
	assert(museum.inventory.detail_name.text == "Broken Thohan")
	assert(museum.inventory.detail_icon.texture != null)
	museum.inventory.hold_button.pressed.emit()
	await process_frame
	assert(museum.hand_item == "" and not control.use())
	assert(museum.hold_for_exhibit(Broken.ITEM))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	assert(control.interaction_hint() == "E — Return Broken Thohan")
	museum._unhandled_input(event)
	assert(Broken.ITEM not in museum.carried_collected and control.sword.visible)
	assert(museum.quickload(path).is_empty())
	assert(Broken.ITEM in museum.carried_collected and not control.sword.visible)
	var transport = museum.inventory_state()
	museum.queue_free()
	await process_frame
	await process_frame
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	current_scene = jungle
	await process_frame
	for room in [jungle.monastery,jungle.magic_shop,jungle.weapon_shop,jungle.departure]: room.set_process(false)
	assert(jungle.apply_inventory_handoff(transport).is_empty())
	assert(jungle.quest_state.museum_control181.owner_state == 1)
	var shop = jungle.magic_shop
	assert(shop.enter_room())
	finish(shop)
	assert(shop.offer_item(Broken.ITEM))
	finish(shop)
	assert(Broken.ITEM in jungle.carried_collected and jungle.quest_state.monastery.globals.GV_KNOWLEDGE_OF_POWER_ORB == 1)
	# Supplied orb; its earned Julian producer has a separate linked route.
	var orb = preload("res://scripts/lol2/monastery_conversation.gd").ORB
	jungle.carried_collected.append(orb)
	assert(shop.offer_item(orb))
	finish(shop)
	assert(shop.offer_item(Broken.ITEM))
	finish(shop)
	assert(Broken.ITEM not in jungle.carried_collected and "jungle:magic_shop:Tho_fixed" in jungle.carried_collected)
	shop.leave_room()
	assert(jungle.quicksave("user://tests/broken_sword_repaired.json").is_empty())
	assert(jungle.quickload("user://tests/broken_sword_repaired.json").is_empty())
	assert(jungle.quest_state.museum_control181.owner_state == 1)
	await RenderingServer.frame_post_draw
	jungle.queue_free()
	await process_frame
	await process_frame
	print("PASS: source broken sword take/return, held-item UI, disk rollback, Museum-to-Jungle carry, Rashar repair with supplied orb and retained exhibit history")
	quit()
