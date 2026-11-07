extends SceneTree
const Forms = preload("res://scripts/lol2/player_form_body.gd")
const Quests = preload("res://scripts/lol2/act_one_quest_state.gd")
func _initialize() -> void: call_deferred("run")
func check_body(scene: Node, form: int) -> void:
	assert(scene.player_form == form)
	assert(scene.player.get_child(0).shape.height == Forms.HEIGHTS[form])
	assert(scene.camera.position.y == Forms.EYES[form]-32)
func settle_and_free(scene: Node) -> void:
	await RenderingServer.frame_post_draw
	scene.queue_free()
	await process_frame
	await process_frame
	await physics_frame
func run() -> void:
	var weapon := "cave:prop641:harvest1:Stalagmite"
	set_meta("lol2_cave_completion",{"collected":[weapon],"equipped_item":weapon,"health":24,"player_form":2})
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum)
	museum.set_physics_process(false)
	check_body(museum,2)
	assert(museum.equipped_item == weapon)
	var path := "user://tests/form_handoff_%d.json" % Time.get_ticks_usec()
	assert(museum.quicksave(path).is_empty())
	var saved: Dictionary = museum.Save.read_save(path).state
	museum.player_form = 0
	museum.apply_save(saved)
	check_body(museum,2)
	var inventory: Dictionary = museum.inventory_state()
	set_meta(museum.CHECKPOINT_KEY,museum.checkpoint_state())
	await settle_and_free(museum)
	# Actual checkpoint startup must preserve the selected cave weapon as well.
	museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(museum)
	museum.set_physics_process(false)
	assert(museum.equipped_item == weapon)
	check_body(museum,2)
	remove_meta(museum.CHECKPOINT_KEY)
	remove_meta("lol2_cave_completion")
	await settle_and_free(museum)
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	jungle.set_physics_process(false)
	assert(jungle.apply_inventory_handoff(inventory).is_empty())
	check_body(jungle,2)
	assert(jungle.quicksave(path).is_empty())
	jungle.player_form = 0
	assert(jungle.quickload(path).is_empty())
	check_body(jungle,2)
	var transfer: Dictionary = jungle.area_handoff()
	await settle_and_free(jungle)
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	hive.get_node("Warriors").set_physics_process(false)
	for form in range(3):
		transfer.inventory.player_form = form
		assert(hive.apply_area_handoff(transfer).is_empty())
		hive.set_physics_process(false)
		check_body(hive,form)
		assert(hive.quicksave(path).is_empty())
		hive.player_form = (form+1)%3
		assert(hive.quickload(path).is_empty())
		check_body(hive,form)
		assert(hive.area_handoff().inventory.player_form == form)
	var before: Dictionary = hive.area_handoff()
	transfer.inventory.player_form = 0.5
	assert(not hive.apply_area_handoff(transfer).is_empty())
	assert(hive.area_handoff() == before)
	transfer.inventory.erase("player_form")
	assert(hive.apply_area_handoff(transfer).is_empty())
	check_body(hive,0)
	await settle_and_free(hive)
	DirAccess.remove_absolute(path)
	print("PASS area forms: cave handoff, Museum checkpoint weapon/form, Jungle/Hive disk state, return form, invalid atomicity, legacy human")
	quit()
