extends SceneTree
const Pickup = preload("res://scripts/lol2/jungle_source_pickups.gd")
const Magic = preload("res://scripts/lol2/magic_shop_state.gd")
func _initialize(): run.call_deferred()
func finish(shop):
	for i in range(1500):
		if not Magic.active(shop.state()): return
		shop.advance(0.1)
	assert(false,"Unfinished MAGIC dialogue")
func run():
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	for room in [scene.monastery,scene.weapon_shop,scene.magic_shop,scene.departure]: room.set_process(false)
	scene.set_physics_process(false)
	var pickup = scene.source_pickups
	# Local source-placement fixture, not an earned walk from the cave.
	var aim: Vector3 = pickup.aim_point()
	scene.player.position = aim + Vector3(0,-scene.camera.position.y,40)
	scene.camera.look_at(aim)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await physics_frame
	assert(pickup.target(),"Original dagger is obstructed at local approach")
	var before = scene.area_handoff()
	var event = InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	pickup._unhandled_input(event)
	assert(Pickup.ITEM in scene.carried_collected and not pickup.sprite.visible)
	assert(scene.quest_state.jungle_dagger_collected)
	assert(scene.set_equipped_item(Pickup.ITEM))
	assert(scene.open_inventory())
	await process_frame
	assert(scene.inventory.item_list.get_item_text(0) == "Th Dagger")
	assert(scene.inventory.item_list.get_item_icon(0) != null)
	scene.inventory.close()
	await process_frame
	var shop = scene.magic_shop
	assert(shop.enter_room())
	finish(shop)
	assert(shop.offer_item(Pickup.ITEM))
	assert(scene.equipped_item.is_empty())
	assert(scene.quicksave("user://tests/jungle_dagger_midtrade.json").is_empty())
	finish(shop)
	assert(Pickup.ITEM not in scene.carried_collected)
	assert("jungle:magic_shop:Dag_Light" in scene.carried_collected)
	shop.leave_room()
	assert(scene.set_equipped_item("jungle:magic_shop:Dag_Light"))
	var path = "user://tests/jungle_dagger_trade.json"
	assert(scene.quicksave(path).is_empty())
	assert(scene.apply_area_handoff(before).is_empty())
	assert(pickup.sprite.visible)
	assert(scene.quickload(path).is_empty())
	assert(not pickup.sprite.visible and Pickup.ITEM not in scene.carried_collected)
	var transferred = JSON.parse_string(JSON.stringify(scene.area_handoff()))
	assert(scene.apply_area_handoff(before).is_empty())
	assert(scene.apply_area_handoff(transferred).is_empty())
	assert(not pickup.sprite.visible)
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	await process_frame
	assert(hive.apply_area_handoff(transferred).is_empty())
	var hive_path = "user://tests/jungle_dagger_hive.json"
	assert(hive.quicksave(hive_path).is_empty())
	assert(hive.quickload(hive_path).is_empty())
	var returned = hive.area_handoff()
	assert(returned.quests.magic_shop == transferred.quests.magic_shop)
	assert(returned.quests.weapon_shop == transferred.quests.weapon_shop)
	assert(scene.apply_area_handoff(returned).is_empty())
	assert(not pickup.sprite.visible and Pickup.ITEM not in scene.carried_collected)
	hive.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	scene.queue_free()
	await process_frame
	print("PASS: source Jungle dagger, E pickup, icon, MAGIC exchange, disk rollback and travel history")
	quit()
