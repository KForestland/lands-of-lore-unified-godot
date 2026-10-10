extends SceneTree
const State = preload("res://scripts/lol2/weapon_shop_state.gd")
const Save = preload("res://scripts/lol2/jungle_save.gd")
func _initialize(): run.call_deferred()
func run():
	var path := "user://tests/weapon_shop_%d.json" % Time.get_ticks_usec()
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	var shop = jungle.weapon_shop
	shop.set_process(false)
	jungle.monastery.set_process(false)
	jungle.magic_shop.set_process(false)
	jungle.departure.set_process(false)
	assert(shop.available and not shop.active())
	jungle.player.position = Vector3(-5310,32,-610)
	shop._process(0.0)
	assert(shop.active() and shop.state().room == "WPNEXT")
	assert(not jungle.is_physics_processing() and not jungle.open_inventory() and not jungle.starting_magic.world_active())
	assert(shop.interact("enter") and shop.state().room == "WPN")
	await process_frame
	await process_frame
	assert(shop.view.background.is_playing() and shop.view.voice.playing and shop.back.disabled)
	assert(jungle.quicksave(path).is_empty())
	shop.advance(1000)
	assert(shop.state().globals.GV_LUTHER_KNOWS_ABOUT_DANIEL == 1)
	assert(jungle.quickload(path).is_empty())
	assert(shop.active() and State.active(shop.state()) and not jungle.is_physics_processing())
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	shop.advance(1000)
	assert(shop.interact("orb"))
	assert(jungle.quest_state.monastery.globals.get("GV_KNOWLEDGE_OF_POWER_ORB",0) == 0)
	assert(jungle.quicksave(path).is_empty())
	shop.advance(1000)
	assert(jungle.quest_state.monastery.globals.GV_KNOWLEDGE_OF_POWER_ORB == 1)
	assert(jungle.quickload(path).is_empty())
	assert(jungle.quest_state.monastery.globals.get("GV_KNOWLEDGE_OF_POWER_ORB",0) == 0)
	shop.advance(1000)
	assert(jungle.quest_state.monastery.globals.GV_KNOWLEDGE_OF_POWER_ORB == 1)
	for action in ["shortsword","longarm","gargoyle"]:
		assert(shop.interact(action))
		shop.advance(1000)
	for name in ["5-Short swd","7-Long arm","42-Gargoyle br"]:
		assert(State.ITEMS[name] in jungle.carried_collected)
	assert(jungle.carried_collected.size() == 3)
	assert(jungle.set_equipped_item(State.ITEMS["5-Short swd"]))
	assert(jungle.quicksave(path).is_empty())
	var bad: Dictionary = Save.read_save(path).state
	bad.quests.weapon_shop.cursor = -1
	assert(not jungle.apply_save(bad).is_empty())
	assert(jungle.quickload(path).is_empty())
	assert(jungle.carried_collected.size() == 3)
	shop.interact("shortsword")
	shop.advance(1000)
	assert(jungle.carried_collected.size() == 3)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://tmp/act1_team_20260927/weapon_shop_live.png")
	shop.leave_room()
	assert(shop.state().room == "WPNEXT")
	shop.leave_room()
	assert(not shop.active() and jungle.is_physics_processing())
	assert(jungle.player.position.x == shop.data.return_pose.x and jungle.player.position.z == shop.data.return_pose.z)
	assert(jungle.quest_state.monastery.globals.GV_KNOWLEDGE_OF_POWER_ORB == 1)
	# The original Julian offer planner consumes the knowledge earned in WPN.
	var plan: Dictionary = preload("res://scripts/lol2/monastery_offer.gd").plan("",jungle.quest_state.monastery.flags,int(jungle.quest_state.monastery.globals.GV_KNOWLEDGE_OF_POWER_ORB))
	assert(plan.sequence == "MOFF_ORB")
	jungle.queue_free()
	await process_frame
	await process_frame
	print("PASS: weapon shop region entry, original media, earned orb knowledge, three item grants, disk rollback and Julian admission")
	quit()
