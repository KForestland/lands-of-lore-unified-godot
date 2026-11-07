extends "res://tests/player_magic_handoff_test.gd"
const Aloe = preload("res://scripts/lol2/cave_aloe.gd")
func consume(scene, id: String, cave := false) -> void:
	if cave:
		var event := InputEventKey.new()
		event.keycode = KEY_I
		event.pressed = true
		scene._unhandled_input(event)
	else: assert(scene.open_inventory())
	await process_frame
	var ids: Array = scene.carried_items() if cave else scene.carried_inventory.collected if scene.get("carried_inventory") != null else scene.carried_collected
	assert(id in ids)
	scene.inventory.select_item(ids.find(id))
	assert(scene.inventory.use_button.visible and scene.inventory.use_button.text == "Use Aloe")
	scene.player_form = 1
	assert(not scene.item_effects.use(id))
	scene.player_form = 0
	scene.inventory.use_button.pressed.emit()
	await process_frame
	await process_frame
	assert(id in scene.item_effects.state().spent and id not in scene.item_effects.carried())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func run() -> void:
	var path := "user://tests/aloe_live_use.json"
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	current_scene = cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready and cave.item_effects != null: break
	assert(cave.walkthrough_ready and cave.item_effects != null)
	cave.set_physics_process(false)
	cave.item_effects.set_process(false)
	cave.starting_magic.set_process(false)
	cave.flying = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Supplied local approach; harvest uses the original source plants and reach check.
	for record in [791,792]:
		var plant = cave.aloe.plants[record]
		cave.player.global_position = plant.global_position+Vector3(0,34,-45)
		cave.camera.look_at(plant.to_global(plant.mesh.center_offset))
		await physics_frame
		for i in 3: assert(cave.aloe.harvest())
	cave.starting_magic.set_health(10)
	var mana: int = cave.player_magic_checkpoint.player.mana
	await consume(cave,Aloe.item_id(791,1),true)
	assert(cave.starting_magic.health() == 10)
	cave.item_effects.advance(2.0/60.0)
	var partial: Dictionary = cave.item_effects.state().duplicate(true)
	var partial_health: int = cave.starting_magic.health()
	assert(partial.aloe.pending == 5 and partial_health > 10)
	assert(cave._quicksave(path).is_empty())
	cave.item_effects.advance(1)
	assert(cave.starting_magic.health() == 16 and cave.item_effects.state().aloe.pending == 0)
	assert(cave._quickload(path).is_empty())
	assert(cave.item_effects.state() == partial and cave.starting_magic.health() == partial_health)
	assert(cave.aloe.count_for(791) == 3 and cave.aloe.count_for(792) == 3)
	assert(cave.player_magic_checkpoint.player.mana == mana)
	var bad: Dictionary = cave._save_state()
	bad.item_effects.spent.append(Aloe.item_id(793,1))
	assert(not cave.WalkthroughSave.validate(bad,cave._checkpoint_count()).is_empty())
	bad = cave._save_state()
	bad.aloe = "invalid"
	assert(not cave.WalkthroughSave.validate(bad,cave._checkpoint_count()).is_empty())
	bad = cave._save_state()
	bad.item_effects.aloe.clock = -1
	assert(not cave.WalkthroughSave.validate(bad,cave._checkpoint_count()).is_empty())
	set_meta("lol2_cave_completion",cave._completion_state())
	await finish(cave)
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum)
	current_scene = museum
	await process_frame
	museum.item_effects.set_process(false)
	museum.set_physics_process(false)
	assert(museum.item_effects.state() == partial and museum.health == partial_health)
	await consume(museum,Aloe.item_id(791,2))
	assert(museum.item_effects.state().aloe.pending == 10)
	assert(museum.quicksave(path).is_empty())
	var carried: Dictionary = museum.inventory_state()
	await finish(museum)
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	current_scene = jungle
	await process_frame
	jungle.item_effects.set_process(false)
	jungle.set_physics_process(false)
	assert(jungle.apply_inventory_handoff(carried).is_empty())
	await consume(jungle,Aloe.item_id(791,3))
	assert(jungle.item_effects.state().aloe.pending == 15)
	assert(jungle.quicksave(path).is_empty())
	assert(jungle.quickload(path).is_empty())
	var handoff: Dictionary = jungle.area_handoff()
	await finish(jungle)
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	current_scene = hive
	await process_frame
	hive.item_effects.set_process(false)
	hive.set_physics_process(false)
	assert(hive.apply_area_handoff(handoff).is_empty())
	await consume(hive,Aloe.item_id(792,1))
	assert(hive.item_effects.state().aloe.pending == 20)
	assert(hive.quicksave(path).is_empty())
	var queued: Dictionary = hive.item_effects.state().duplicate(true)
	assert(hive.open_inventory())
	hive.item_effects.advance(1)
	assert(hive.item_effects.state() == queued)
	hive.inventory.close()
	await process_frame
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hive.item_effects.advance(1)
	assert(hive.starting_magic.health() <= 30 and hive.item_effects.state().aloe.pending == 0)
	assert(hive.quickload(path).is_empty() and hive.item_effects.state() == queued)
	hive.starting_magic.set_health(30)
	await consume(hive,Aloe.item_id(792,2))
	hive.item_effects.advance(1)
	assert(hive.starting_magic.health() == 30 and hive.item_effects.state().aloe.pending == 0)
	await finish(hive)
	print("PASS Aloe actual harvest/UI consumption, gradual health/no mana effect, full-health consumption, form gate, cave no-respawn, partial disk rollback and four-area healing transport")
	quit()
