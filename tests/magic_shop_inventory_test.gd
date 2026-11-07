extends SceneTree
const State = preload("res://scripts/lol2/magic_shop_state.gd")
func _initialize() -> void: run.call_deferred()
func finish(shop) -> void:
	for i in range(1500):
		if not State.active(shop.state()): return
		shop.advance(0.1)
	assert(false,"Shop sequence never finished")
func run() -> void:
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	var shop=scene.magic_shop
	shop.set_process(false)
	scene.monastery.set_process(false)
	scene.weapon_shop.set_process(false)
	assert(shop.enter_room())
	finish(shop)
	shop.leave_room()
	assert(shop.enter_room())
	finish(shop)
	assert(shop.offer_item(""))
	finish(shop)
	assert(not shop.state().timer_armed)
	# Original sprite hit rectangles, grant order and one-shot flags.
	for id in [0,1,5,4,3,2]:
		var p: Array=shop.Shop.SPRITES[id]
		assert(shop.sprite_nodes[id].visible)
		var count: int=scene.carried_collected.size()
		assert(shop.click(Vector2i(p[0]+1,p[1]+1)))
		assert(scene.carried_collected.size()==count+1 and shop.state().pending_items.is_empty())
		assert(not shop.sprite_nodes[id].visible)
		finish(shop)
	var earned: Array=scene.carried_collected.duplicate()
	assert(earned.size()==6)
	var path: String="user://tests/magic_shop_inventory.json"
	assert(scene.quicksave(path).is_empty())
	scene.carried_collected.clear()
	assert(scene.quickload(path).is_empty() and scene.carried_collected==earned)
	shop=scene.magic_shop
	assert(shop.state().pending_items.is_empty())
	shop.leave_room()
	assert(scene.open_inventory())
	await process_frame
	for i in range(scene.inventory.item_list.item_count):
		assert(scene.inventory.item_list.get_item_icon(i)!=null)
		assert(scene.inventory.item_list.get_item_text(i)!="Unidentified item")
	scene.inventory.close()
	await process_frame
	var transfer: Dictionary=scene.area_handoff()
	assert(scene.Save.validate_inventory(transfer.inventory).is_empty())
	await RenderingServer.frame_post_draw
	scene.queue_free()
	await process_frame
	print("PASS: six MAGIC sprite grants, original icons, one-shot flags, disk rollback and travel inventory")
	quit()
