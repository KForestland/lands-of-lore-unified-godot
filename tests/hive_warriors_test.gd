extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var guards = scene.get_node("Warriors")
	var pillar = scene.get_node("QuestPillar")
	guards.set_process(false)
	pillar.set_process(false)
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.carried_inventory = {"collected":[scene.Save.Shared.Museum.SWORD],"equipped_item":scene.Save.Shared.Museum.SWORD,"equipped_armor":""}
	scene.player.position = guards.POSITIONS[0]+Vector3(0,32,65)
	scene.camera.look_at(guards.POSITIONS[0]+Vector3(0,35,0))
	for i in range(2): await physics_frame
	paused = true
	assert(not guards.strike())
	paused = false
	scene.flying = true
	assert(not guards.strike())
	scene.flying = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	assert(not guards.strike())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var obstruction := StaticBody3D.new()
	var obstruction_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60,100,4)
	obstruction_shape.shape = box
	obstruction.add_child(obstruction_shape)
	obstruction.position = guards.POSITIONS[0]+Vector3(0,40,30)
	root.add_child(obstruction)
	for i in range(2): await physics_frame
	assert(not guards.strike() and guards.enemies[0] == 24)
	obstruction.queue_free()
	await physics_frame
	scene.player_form=2
	guards._process(0.5)
	assert(guards.strike() and guards.enemies[0]==23,"Lizard must not use the held sword's damage")
	guards.restore(scene.Save.Shared.Quests.initial_encounter())
	scene.player_form=1
	assert(guards.strike() and guards.enemies[0]==12,"Beast uses provisional natural strength")
	assert(scene.carried_inventory.equipped_item==scene.Save.Shared.Museum.SWORD,"Morph discarded held gear")
	guards.restore(scene.Save.Shared.Quests.initial_encounter())
	scene.player_form=0
	guards._process(0.5)
	assert(guards.strike() and guards.enemies[0] == 16)
	assert(not guards.strike())
	guards._process(0.5)
	assert(guards.strike() and guards.enemies[0] == 8)
	guards._process(0.5)
	assert(guards.strike() and guards.enemies[0] == 0)
	assert(pillar.moving and pillar.blocker.collision_layer == 0)
	assert(not guards.bodies[0].visible and guards.bodies[0].collision_layer == 0)
	pillar.advance(0.4)
	var path := "user://tests/guardian_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(path).is_empty())
	guards.restore(scene.Save.Shared.Quests.initial_encounter())
	assert(pillar.blocker.collision_layer == 1)
	assert(scene.quickload(path).is_empty())
	assert(guards.enemies[0] == 0 and guards.enemies[1] == 24)
	assert(is_equal_approx(pillar.elapsed,0.4) and pillar.moving)
	var invalid: Dictionary = scene.area_handoff()
	var saved_health: int = guards.health
	invalid.quests.hive_encounter.health = true
	assert(not scene.apply_area_handoff(invalid).is_empty())
	assert(guards.health == saved_health and guards.enemies[0] == 0)
	pillar.advance(1)
	assert(pillar.opened)
	# Enemy strikes and death freeze walking; leaving reach cancels the windup.
	guards.restore(scene.Save.Shared.Quests.initial_encounter())
	scene.set_physics_process(false)
	scene.player.position = guards.POSITIONS[1]+Vector3(0,32,50)
	scene.camera.look_at(guards.POSITIONS[1]+Vector3(0,35,0))
	for i in range(2): await physics_frame
	guards._process(1.0)
	assert(guards.health == 30)
	guards._process(0.5)
	assert(guards.health == 24)
	for i in range(4): guards._process(1.5)
	assert(guards.health == 0 and not scene.is_physics_processing())
	assert(not guards.strike())
	var retry := InputEventKey.new()
	retry.keycode = KEY_R
	retry.pressed = true
	scene._unhandled_input(retry)
	assert(guards.health == 30 and scene.is_physics_processing())
	assert(guards.enemies == [24,24] and pillar.blocker.collision_layer == 1)
	DirAccess.remove_absolute(path)
	scene.queue_free()
	await process_frame
	print("Hive guardians: player hit/cooldown, defeat event, collider release, partial pillar save/load, invalid state, enemy damage/death/retry passed")
	quit()
