extends "res://tests/hive_quest_walk_test.gd"
func run() -> void:
	Engine.time_scale = 8
	Engine.physics_ticks_per_second = 480
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	# Local return fixture: earned flute and completed rescue supplied once.
	var quests = scene.Save.Quests.initial()
	quests.shared_flag_38 = 1
	quests.hive_room_entered = true
	quests.conversation = {"started":true,"completed":true,"section_cursor":3,"elapsed":5.0}
	quests.hive_nest = {"phase":3,"elapsed":0.0}
	quests.hive_chasm = {"activated":true,"elapsed":scene.Save.Quests.CHASM_DURATION}
	quests.hive_encounter = scene.Save.Quests.initial_encounter()
	quests.hive_encounter.enemies = [0,0]
	quests.hive_encounter.pillar_elapsed = 1.0
	var flute: String = preload("res://scripts/lol2/monastery_conversation.gd").FLUTE
	var state := {"inventory":{"collected":[scene.SWORD_ITEM_ID,flute],"equipped_item":scene.SWORD_ITEM_ID,"equipped_armor":""},"quests":quests}
	if not check(scene.apply_area_handoff(state).is_empty(),"Return fixture rejected"): return
	scene.player.position = Vector3(4181,42,2377)
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	root.grab_focus()
	for frame in range(3): await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	routes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_flute_return_routes.json"))
	if not await walk("monastery_to_hive",true): return
	for tick in range(180):
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/lol2/hive_review.tscn": break
	if not check(is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/lol2/hive_review.tscn","Return failed to enter Hive"): return
	scene = current_scene
	scene.set_physics_process(false)
	if not check(flute in scene.carried_inventory.collected,"Hive return lost flute"): return
	if not await walk("hive_return_to_gate"): return
	print("PASS: supplied monastery exit/flute/rescue state walks through Jungle and real Hive transition to curse control region, without later repositioning")
	current_scene.queue_free()
	await process_frame
	quit()
