extends SceneTree
func _initialize() -> void: run.call_deferred()
func wait_for_scene(path: String) -> void:
	for i in range(180):
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == path and current_scene.has_node("HiveRoute"): return
	assert(false,"Route did not reach destination")
func run() -> void:
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	current_scene = jungle
	await process_frame
	var quests = jungle.Save.Quests.initial()
	quests.shared_flag_38 = 1
	quests.hive_room_entered = true
	quests.conversation = {"started":true,"completed":true,"section_cursor":3,"elapsed":5.0}
	quests.hive_nest = {"phase":3,"elapsed":0.0}
	quests.hive_encounter = jungle.Save.Quests.initial_encounter()
	quests.hive_encounter.enemies = [0,24]
	quests.hive_encounter.pillar_elapsed = 1.0
	var state := {"inventory":{"collected":[jungle.SWORD_ITEM_ID],"equipped_item":jungle.SWORD_ITEM_ID,"equipped_armor":""},"quests":quests}
	assert(jungle.apply_area_handoff(state).is_empty())
	var route = jungle.get_node("HiveRoute")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	route._physics_process(0)
	assert(route.armed)
	paused = true
	assert(not route.begin_transition())
	paused = false
	jungle.flying = true
	assert(not route.begin_transition())
	jungle.flying = false
	# Place the capsule inside the verified trigger and let gravity ground it.
	var center := Vector2.ZERO
	for point in route.route.polygon: center += Vector2(point[0],point[1])/route.route.polygon.size()
	jungle.player.position = Vector3(center.x,route.route.floor+34,center.y)
	await wait_for_scene("res://scenes/lol2/hive_review.tscn")
	var hive = current_scene
	assert(hive.carried_inventory.equipped_item == jungle_sword())
	assert(hive.get_node("ConversationReview").completed)
	assert(hive.get_node("Warriors").enemies == [0,24])
	assert(hive.get_node("QuestPillar").opened)
	assert(not has_meta("lol2_hive_route_handoff"))
	for i in range(30): await physics_frame
	assert(current_scene == hive and hive.player.is_on_floor())
	assert(Vector2(hive.player.position.x,hive.player.position.z).distance_to(Vector2(848,-4447)) < 1)
	var expected_hive_dawn: Dictionary=hive.dawn20.initial()
	route = hive.get_node("HiveRoute")
	assert(route.armed)
	center = Vector2.ZERO
	for point in route.route.polygon: center += Vector2(point[0],point[1])/route.route.polygon.size()
	hive.player.position = Vector3(center.x,route.route.floor+34,center.y)
	await wait_for_scene("res://scenes/lol2/jungle_walkthrough.tscn")
	jungle = current_scene
	for i in range(30): await physics_frame
	assert(current_scene == jungle and jungle.player.is_on_floor())
	assert(Vector2(jungle.player.position.x,jungle.player.position.z).distance_to(Vector2(-6332,4697)) < 1)
	assert(jungle.equipped_item == jungle_sword())
	var after: Dictionary = jungle.quest_state.duplicate(true)
	var expected: Dictionary = quests.duplicate(true)
	expected.jungle_exit_woman=jungle.exit_woman.initial()
	assert(jungle.exit_woman.Packet.validate(after.jungle_exit_woman).is_empty())
	# The return creates a new controller; its runtime epoch is not gameplay state.
	assert(int(after.jungle_exit_woman.conversation.prop.generation)>0)
	expected.jungle_exit_woman.conversation.prop.generation=int(after.jungle_exit_woman.conversation.prop.generation)
	expected.hive_dawn20=expected_hive_dawn
	expected.jungle_bacatta=jungle.bacatta.initial()
	if is_instance_valid(jungle.bacatta65): expected.jungle_bacatta65=jungle.bacatta65.initial()
	if is_instance_valid(jungle.bacatta57): expected.jungle_bacatta57=jungle.bacatta57.initial()
	if is_instance_valid(jungle.village_alarm): expected.jungle_village_alarm=jungle.village_alarm.initial()
	if is_instance_valid(jungle.inner_gate): expected.jungle_inner_gate=jungle.inner_gate.initial()
	if is_instance_valid(jungle.chief_hut): expected.jungle_chief_hut=jungle.chief_hut.initial()
	if is_instance_valid(jungle.kityara): expected.jungle_kityara=jungle.kityara.initial()
	if is_instance_valid(jungle.drunk): expected.jungle_drunk=jungle.drunk.initial()
	expected.jungle_exit_encounter=jungle.exit_encounter.initial()
	if is_instance_valid(jungle.kelsrick): expected.jungle_kelsrick=jungle.kelsrick.initial()
	if is_instance_valid(jungle.dawn): expected.jungle_dawn=jungle.dawn.initial()
	if is_instance_valid(jungle.actor62): expected.jungle_actor62=jungle.actor62.initial()
	# Entering Hive materializes the optional legacy rune-room checkpoint.
	expected.jungle_harvest = preload("res://scripts/lol2/jungle_harvest_state.gd").initial()
	expected.jungle_beehives = preload("res://scripts/lol2/jungle_beehives_state.gd").initial()
	expected.hive_reaver_amber = preload("res://scripts/lol2/hive_reaver_amber_state.gd").initial()
	expected.hive_net_exile = preload("res://scripts/lol2/hive_net_exile.gd").initial()
	expected.hive_executioner_live = preload("res://scripts/lol2/hive_executioner_live.gd").initial()
	expected.hive_rune_entry = preload("res://scripts/lol2/hive_rune_entry_state.gd").initial()
	var ambush=preload("res://scripts/lol2/hive_ambush_state.gd")
	assert(ambush.validate(after.hive_ambush).is_empty())
	expected.hive_ambush=ambush.initial()
	assert(after.hive_ambush.actors["35"].elapsed>=0 and after.hive_ambush.actors["35"].elapsed<ambush.EATING)
	expected.hive_ambush.actors["35"].elapsed=after.hive_ambush.actors["35"].elapsed
	expected.hive_rune_population_schema=1
	expected.hive_rune_population=preload("res://scripts/lol2/hive_rune_population_state.gd").initial()
	var retired_slot: Dictionary=after.hive_rune_population.slots["32"]
	assert(int(retired_slot.phase) in [1,2] and retired_slot.counter>=0 and retired_slot.counter<=5)
	expected.hive_rune_population.slots["32"].phase=retired_slot.phase
	expected.hive_rune_population.slots["32"].counter=retired_slot.counter
	expected.hive_rune_population.fraction=after.hive_rune_population.fraction
	expected.hive_boulder_actor_schema = 1
	expected.hive_boulder_contact_schema = 1
	expected.hive_boulder_contact = preload("res://scripts/lol2/hive_boulder_contact_state.gd").initial()
	expected.hive_boulder_audio_schema = 1
	expected.hive_boulder_audio = preload("res://scripts/lol2/hive_boulder_audio_state.gd").initial()
	expected.hive_boulder_actors = preload("res://scripts/lol2/hive_boulder_actor_state.gd").initial()
	expected.hive_boulder_surfaces = preload("res://scripts/lol2/hive_boulder_sequence.gd").initial()
	expected.hive_return_population = preload("res://scripts/lol2/hive_return_population_state.gd").initial()
	for id in ["27","28","29"]: expected.hive_return_population.actors[id].active=true
	assert(after.hive_curse.running and not after.hive_curse.enabled)
	assert(after.hive_curse.remaining > 0 and after.hive_curse.remaining < expected.hive_curse.remaining,"Live Hive timer did not survive route round trip")
	after.erase("hive_curse")
	expected.erase("hive_curse")
	for key in after:
		if not expected.has(key) or after[key] != expected[key]: print("Handoff mismatch ",key,": ",after[key]," expected ",expected.get(key))
	if after != expected:
		push_error("Quest handoff differs")
		quit(1)
		return
	assert(not has_meta("lol2_hive_route_handoff"))
	print("Hive routes: grounded source trigger round trip, arrival floors, no bounce, sword and completed quest/guardian/pillar transport passed")
	current_scene.queue_free()
	await process_frame
	quit()
func jungle_sword() -> String: return "museum:item11:Fine_Longsword"
