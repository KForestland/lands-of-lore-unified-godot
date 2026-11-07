extends SceneTree
func _initialize() -> void:
	run.call_deferred()

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	var chasm = scene.get_node("Chasm")
	chasm.set_physics_process(false)
	var guards = scene.get_node("Warriors")
	guards.set_process(false)
	scene.player.position = Vector3(-925,-202.96,-6082)
	scene.camera.look_at(chasm.trigger.global_position+Vector3(0,36,0))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in range(2): await physics_frame
	assert(not guards.aimed_hit().is_empty() and guards.aimed_hit().collider == chasm.trigger)
	guards._process(0)
	assert("Loose rock" in guards.label.text)
	# Overlay browsing and movement/conversation/death locks reject the same hit.
	paused = true
	assert(not guards.strike() and not chasm.activated)
	paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	assert(not guards.strike() and not chasm.activated)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	scene.flying = true
	assert(not guards.strike() and not chasm.activated)
	scene.flying = false
	guards.health = 0
	assert(not guards.strike() and not chasm.activated)
	guards.health = 30
	var actor = scene.get_node("ConversationReview")
	actor.started = true
	assert(not guards.strike() and not chasm.activated)
	actor.started = false
	# A real intervening collider blocks the rock ray.
	var obstruction := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30,150,100)
	collision.shape = box
	obstruction.add_child(collision)
	root.add_child(obstruction)
	obstruction.position = Vector3(-960,-175,-6050)
	for i in range(2): await physics_frame
	click()
	assert(not chasm.activated)
	obstruction.queue_free()
	for i in range(2): await physics_frame
	guards.cooldown = 0
	click()
	assert(chasm.activated and chasm.trigger.collision_layer == 0)
	assert(guards.enemies == [24,24])
	guards._process(0.5)
	assert("Rocks collapsing" in guards.label.text)
	chasm.advance(1)
	click()
	assert(chasm.elapsed == 1) # Repeated strikes cannot restart progress.
	scene.queue_free()
	await process_frame
	print("Hive chasm input: actual mouse strike, wall occlusion, pause/cursor/flight/death/speech guards, hint and no-repeat passed")
	quit()
