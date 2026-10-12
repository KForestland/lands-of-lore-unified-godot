extends SceneTree
const Combat = preload("res://scripts/lol2/cave_roach.gd")
const Weapon = preload("res://scripts/lol2/cave_stalagmite.gd")
var scene: Node
func _initialize() -> void: call_deferred("run")
func open_cave() -> void:
	scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	assert(scene.walkthrough_ready and scene.roach != null)
	scene.set_physics_process(false)
	scene.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	scene._unhandled_input(event)
func run() -> void:
	await open_cave()
	assert(scene.roach.spawn.is_equal_approx(Vector3(-1900,4,-5627)+scene.native_translation))
	# Initial nearby spawn/equipment fixtures; hits use production mouse input,
	# aim, reach and collision rays. No kill/collect/exit objective is installed.
	scene.player.global_position = scene.roach.body.global_position+Vector3(0,34,30)
	scene.camera.look_at(scene.roach.body.global_position+Vector3.UP*6)
	scene.flying = false
	await physics_frame
	click()
	assert(scene.roach.model.enemy_health == 24, "Weapon must be selected")
	scene.stalagmites.restore([Weapon.item_id(641,1)])
	assert(scene.set_equipped_item(Weapon.item_id(641,1)))
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100,100,3)
	collider.shape = shape
	wall.add_child(collider)
	scene.add_child(wall)
	wall.global_position = scene.camera.global_position.lerp(scene.roach.body.global_position+Vector3.UP*6,0.5)
	await physics_frame
	click()
	assert(scene.roach.model.enemy_health == 24 and scene.roach.model.strike_remaining > 0, "Wall blocks a swing and consumes cooldown")
	wall.free()
	await physics_frame
	scene.roach.model.strike_remaining = 0.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(argument.trim_prefix("--capture=")) == OK)
	var path := "user://tests/roach_%d.json" % Time.get_ticks_usec()
	scene.roach.model.phase = scene.roach.Model.Phase.WINDUP
	scene.roach.model.phase_remaining = 0.1
	scene.roach._sync(0.0,false)
	assert(scene._quicksave(path).is_empty())
	var expected: Dictionary = scene._save_state()
	scene.roach.tick(0.11)
	assert(scene.roach.model.player_health == 24, "Original-frame-timed impact occurs once")
	assert(scene._quickload(path).is_empty())
	assert(scene._save_state() == expected)
	scene.roach.tick(0.11)
	assert(scene.roach.model.player_health == 24)
	scene.roach.tick(0.1)
	assert(scene.roach.model.player_health == 24, "Recovery cannot repeat the impact")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var paused: Dictionary = scene.roach.snapshot()
	scene.roach.tick(2.0)
	assert(scene.roach.snapshot() == paused)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in range(3):
		scene.camera.look_at(scene.roach.body.global_position+Vector3.UP*6)
		click()
		if i<2: scene.roach.tick(0.46)
	assert(scene.roach.model.enemy_health == 0)
	assert(scene.roach.body.collision_layer == 0 and not scene.roach.model.complete)
	scene.roach.tick(0.4)
	assert(scene._quicksave(path).is_empty())
	expected = scene._save_state()
	scene.free()
	await process_frame
	await open_cave()
	assert(scene._quickload(path).is_empty())
	assert(scene._save_state() == expected)
	assert(scene.roach.body.collision_layer == 0)
	scene.roach.tick(3.0)
	assert(not scene.roach.mesh.visible)
	for pair in scene.occluder_pairs+scene.light_pairs:
		if pair[0] == scene.roach.mesh: assert(not pair[1].visible)
	scene.roach.model.player_health = 0
	assert(not scene._quicksave(path).is_empty())
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	scene._unhandled_input(key)
	assert(scene.roach.model.player_health == 30 and scene.roach.model.enemy_health == 0)
	var bad: Dictionary = expected.roach.duplicate(true)
	bad.phase = 0
	assert(not Combat.validate(bad))
	bad = expected.roach.duplicate(true)
	bad.player_health = NAN
	assert(not Combat.validate(bad))
	DirAccess.remove_absolute(path)
	scene.roach.model.player_health = 24
	var completion: Dictionary = scene._completion_state()
	assert(completion.health == 24)
	set_meta("lol2_cave_completion",completion)
	scene.free()
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state = "complete"
	root.add_child(museum)
	museum.set_physics_process(false)
	assert(museum.health == 24 and museum.equipped_item == Weapon.item_id(641,1))
	var museum_path := "user://tests/roach_museum_%d.json" % Time.get_ticks_usec()
	assert(museum.quicksave(museum_path).is_empty())
	var saved = preload("res://scripts/lol2/museum_save.gd").read_save(museum_path)
	assert(saved.error.is_empty() and saved.state.checkpoint.health == 24)
	museum.health = 30
	museum.apply_save(saved.state)
	assert(museum.health == 24)
	DirAccess.remove_absolute(museum_path)
	museum.free()
	print("PASS continuous cave ROACH: source placement, weapon/mouse strikes, timed impact/save rollback, pause, defeat/new-scene persistence, collision/visual removal, recovery")
	quit()
