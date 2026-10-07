extends SceneTree
const State = preload("res://scripts/lol2/weapon_shop_state.gd")
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
func _initialize(): run.call_deferred()
func run():
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	for room in [scene.monastery,scene.weapon_shop,scene.magic_shop,scene.departure]: room.set_process(false)
	var shop = scene.weapon_shop
	# Supplied inventory: Julian's actual producer is tested separately.
	scene.carried_collected = [Speech.ORB,"jungle:item51:Th_Dagger"]
	scene.quest_state.monastery.globals["GV_KNOWLEDGE_OF_POWER_ORB"] = 1
	assert(shop.enter_exterior() and shop.interact("enter"))
	shop.advance(1000)
	assert(shop.interact("orb") and shop.state().sequence == "orb_preknown")
	shop.advance(1000)
	assert(shop.offer_item("jungle:item51:Th_Dagger"))
	shop.advance(1000)
	assert("jungle:item51:Th_Dagger" in scene.carried_collected)
	assert(shop.offer_item(Speech.ORB))
	assert(Speech.ORB not in scene.carried_collected)
	assert(State.ITEMS["9-Firestorm"] not in scene.carried_collected)
	var path = "user://tests/weapon_shop_orb_trade.json"
	assert(scene.quicksave(path).is_empty())
	shop.advance(1000)
	assert(State.ITEMS["9-Firestorm"] in scene.carried_collected)
	assert(scene.quickload(path).is_empty())
	assert(State.ITEMS["9-Firestorm"] not in scene.carried_collected)
	shop.advance(1000)
	assert(scene.carried_collected.count(State.ITEMS["9-Firestorm"]) == 1)
	assert(State.flag(shop.state(),63))
	shop.leave_room()
	shop.leave_room()
	assert(scene.set_equipped_item(State.ITEMS["9-Firestorm"]))
	assert(scene.quicksave(path).is_empty())
	assert(scene.quickload(path).is_empty())
	assert(scene.equipped_item == State.ITEMS["9-Firestorm"])
	assert(scene.Save.validate_inventory(scene.area_handoff().inventory).is_empty())
	await RenderingServer.frame_post_draw
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: preknown orb response, dagger retained, orb consumed, delayed Firestorm, partial disk rollback and equipped travel")
	quit()
