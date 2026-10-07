extends SceneTree

const State = preload("res://scripts/lol2/cave_encounter_state.gd")
var view: Node
var checks := 0
var failures := 0
var directory := "user://captures/encounter_validation"

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func tick(count: int = 1) -> void:
	for frame in range(count):
		await physics_frame
		view._physics_process(1.0 / 60.0)
		await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	await tick()

func capture(label: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(label + ".png"))

func check_actor_pixels() -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var shown: PackedByteArray = view.index_view.get_texture().get_image().get_data()
	view.enemy_mesh.visible = false
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var hidden: PackedByteArray = view.index_view.get_texture().get_image().get_data()
	check(shown != hidden, "Moving creature contributes visible indexed pixels")
	print("Actor world position ", view.enemy_mesh.global_position, " player ", view.player.global_position)
	view.enemy_mesh.visible = true
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	check(view.index_view.get_texture().get_image().get_data() == shown, "Actor visibility restores indexed pixels exactly")

func check_animation_frames() -> void:
	view.animation.set_view(7)
	check(view.animation.textures.size() == 9 and view.animation_materials.size() == 3, "Nine source frames loaded into three isolated render passes")
	var other: MeshInstance3D
	for child in view.dummy_root.get_children():
		if child.get_meta("dummy_id", "") == "roach_b": other = child
	var static_texture: Texture2D = other.mesh.material.get_shader_parameter("indices")
	var unique: Array = []
	var canvas: Vector2 = view.enemy_mesh.mesh.size
	var centre: Vector3 = view.enemy_mesh.mesh.center_offset
	for index in range(9):
		view.animation.frame_index = index
		view._apply_enemy_frame()
		check(view.animation_materials.all(func(material): return material.get_shader_parameter("indices") == view.animation.textures[index]), "Frame textures synchronized across render passes")
		check(view.enemy_mesh.mesh.size == canvas and view.enemy_mesh.mesh.center_offset == centre, "Frame changes preserve canvas and origin")
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var pixels: PackedByteArray = view.index_view.get_texture().get_image().get_data()
		if not unique.has(pixels): unique.append(pixels)
		root.get_texture().get_image().save_png(directory.path_join("animation_%d.png" % (733 + index)))
	check(unique.size() == 9, "All nine poses produce distinct rendered indexed pixels")
	check(other.mesh.material.get_shader_parameter("indices") == static_texture, "Animating actor leaves other roach dummy unchanged")
	view.animation.reset()
	view._update_enemy_direction()
	view._apply_enemy_frame()

func check_directional_views() -> void:
	check(view.animation.view_textures.size() == 8 and view.animation.view_textures.all(func(frames): return frames.size() == 9), "Eight recovered views each contain nine frames")
	var unique: Array = []
	var canvas: Vector2 = view.enemy_mesh.mesh.size
	var centre: Vector3 = view.enemy_mesh.mesh.center_offset
	for slot in range(8):
		view.animation.set_view(slot)
		view.animation.frame_index = 0
		view._apply_enemy_frame()
		check(view.animation_materials.all(func(material): return material.get_shader_parameter("indices") == view.animation.textures[0]), "Directional view synchronized across render passes")
		check(view.enemy_mesh.mesh.size == canvas and view.enemy_mesh.mesh.center_offset == centre, "Directional views preserve shared canvas/anchor")
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var pixels: PackedByteArray = view.index_view.get_texture().get_image().get_data()
		if not unique.has(pixels): unique.append(pixels)
		root.get_texture().get_image().save_png(directory.path_join("direction_%d.png" % slot))
	check(unique.size() == 8, "All eight directions produce distinct visible indexed pixels")
	var facing: Vector2 = view.enemy_facing
	var relative: Vector3 = view.camera.global_position - view.enemy.global_position
	view.enemy_facing = Vector2(relative.x, -relative.z)
	view._update_enemy_direction()
	check(view.animation.view_slot == 0, "Facing camera selects original front view")
	view.enemy_facing = -view.enemy_facing
	view._update_enemy_direction()
	check(view.animation.view_slot == 4, "Facing away selects original opposite view")
	view.enemy_facing = facing
	view._update_enemy_direction()
	view._apply_enemy_frame()

func check_action_frames() -> void:
	var canvas: Vector2 = view.enemy_mesh.mesh.size
	var centre: Vector3 = view.enemy_mesh.mesh.center_offset
	for action in [5, 14]:
		view.animation.play_action(action)
		var unique: Array = []
		for index in range(view.animation.frame_count):
			view.animation.frame_index = index
			view._apply_enemy_frame()
			check(view.animation_materials.all(func(material): return material.get_shader_parameter("indices") == view.animation.textures[index]), "Action frame synchronized across render passes")
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			var pixels: PackedByteArray = view.index_view.get_texture().get_image().get_data()
			if not unique.has(pixels): unique.append(pixels)
			if index in [0, 7, 10, 12, view.animation.frame_count - 1]:
				root.get_texture().get_image().save_png(directory.path_join("action_%d_frame_%d.png" % [action, index]))
		check(unique.size() >= 8, "Recovered action produces visible animated changes")
		check(view.enemy_mesh.mesh.size == canvas and view.enemy_mesh.mesh.center_offset == centre, "Actions preserve shared canvas and source anchor")
	view.animation.reset()
	view._update_enemy_direction()
	view._apply_enemy_frame()

func walk_toward(destination: Vector3, stop_distance: float) -> void:
	view.player.look_at(Vector3(destination.x, view.player.global_position.y, destination.z))
	view.camera.rotation = Vector3(-0.15, 0, 0)
	await key(KEY_W, true)
	for frame in range(240):
		var gap: Vector3 = destination - view.player.global_position
		if Vector2(gap.x, gap.z).length() <= stop_distance:
			break
		await tick()
	await key(KEY_W, false)
	await tick()

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--encounter-capture="):
			directory = argument.trim_prefix("--encounter-capture=")
	DirAccess.make_dir_recursive_absolute(directory)
	view = load("res://scenes/lol2/cave_encounter.tscn").instantiate()
	root.add_child(view)
	for frame in range(120):
		await process_frame
		if view.encounter_ready: break
	check(view.encounter_ready, "Encounter initializes")
	if not view.encounter_ready:
		quit(1)
		return
	view.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await tick(5)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Rendered input captures mouse")
	check(view.enemy_copies.size() == 2, "Dynamic actor has indexed occlusion and light copies")
	await capture("start")
	var original_enemy: Vector3 = view.enemy.global_position
	await tick(60)
	check(view.enemy.global_position.distance_to(original_enemy) > 15, "Visible enemy pursues through actual physics")
	check(view.enemy.is_on_floor() and view.player.is_on_floor(), "Player and creature stay on recovered floor")
	check(view.enemy_copies.all(func(copy): return copy.global_transform.is_equal_approx(view.enemy_mesh.global_transform)), "Moving render copies stay synchronized")
	view.camera.look_at(view.enemy.global_position + Vector3.UP * 6)
	await capture("approaching")
	await check_actor_pixels()
	await check_animation_frames()
	await check_directional_views()
	await check_action_frames()
	# A physical wall must block both attack queries.
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(16, 100, 16)
	shape.shape = box
	blocker.add_child(shape)
	view.add_child(blocker)
	blocker.global_position = view.camera.global_position.lerp(view.enemy.global_position + Vector3.UP * 6, 0.5)
	await physics_frame
	await physics_frame
	view.camera.look_at(view.enemy.global_position + Vector3.UP * 6)
	view.encounter.strike_remaining = 0
	await click()
	check(view.encounter.enemy_health == State.ENEMY_HEALTH, "Physical wall blocks player strike")
	view.encounter.phase = State.Phase.WINDUP
	view.encounter.phase_remaining = 0.001
	var health: int = view.encounter.player_health
	await tick()
	check(view.encounter.player_health == health, "Physical wall prevents enemy impact")
	check(view.animation.frame_index == 12, "Blocked impact displays native event frame in same tick")
	check(view.animation.action_key == 5 and view.enemy_mesh.position.y == 0.0, "Combat phase uses recovered action sequence without placeholder lift")
	blocker.queue_free()
	await physics_frame
	await physics_frame
	# Released mouse pauses the fight; the recapture click never attacks.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var phase: int = view.encounter.phase
	var timer: float = view.encounter.phase_remaining
	var animation_time: float = view.animation.elapsed
	await tick(30)
	check(view.encounter.phase == phase and view.encounter.phase_remaining == timer, "Released mouse pauses attack timers")
	check(view.animation.elapsed == animation_time, "Released mouse pauses animation clock")
	view.encounter.strike_remaining = 0
	await click()
	check(view.encounter.enemy_health == State.ENEMY_HEALTH, "Recapture click does not strike")
	# Retry then complete the real loop using mouse attacks, E and physical W.
	await key(KEY_R, true)
	await key(KEY_R, false)
	check(view.encounter.enemy_health == 24 and view.encounter.player_health == 30, "R restarts both combatants")
	await tick(15)
	for frame in range(180):
		view.camera.look_at(view.enemy.global_position + Vector3.UP * 6)
		if frame % 30 == 0: await click()
		else: await tick()
		if view.encounter.enemy_health == 0: break
	check(view.encounter.enemy_health == 0 and view.encounter.player_health > 0, "Player wins encounter through timed mouse strikes")
	check(view.enemy_mesh.visible and view.animation.action_key == 14, "Defeat begins recovered collapse sequence")
	check(view.enemy.collision_layer == 0, "Defeated creature cannot leave an invisible blocker")
	check(not view.encounter.complete, "Defeat alone does not finish section")
	var collapse_time: float = view.animation.elapsed
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await tick(30)
	check(view.animation.elapsed == collapse_time, "Released mouse pauses collapse playback")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await tick(160)
	check(not view.enemy_mesh.visible and view.enemy_copies.all(func(copy): return not copy.visible), "Completed collapse removes all actor render passes")
	await capture("defeated")
	await walk_toward(view.collectible.target_position(), 48)
	view.camera.look_at(view.collectible.target_position())
	await tick()
	check(view.interaction_available, "Player walks into sample interaction range")
	await key(KEY_E, true)
	await tick()
	await key(KEY_E, false)
	check(view.collectible.collected, "E collects the sample after combat")
	check(not view.encounter.complete, "Sample still requires reaching passage")
	await walk_toward(view.exit_position, 15)
	if not view.encounter.complete:
		print("Exit approach: player=", view.player.global_position, " exit=", view.exit_position, " slides=", view.player.get_slide_collision_count())
		for i in range(view.player.get_slide_collision_count()):
			print("Blocked by ", view.player.get_slide_collision(i).get_collider(), " at ", view.player.get_slide_collision(i).get_position())
	check(view.encounter.complete and view.encounter.completion_count == 1, "Walking to passage fires progression once")
	await tick(30)
	check(view.encounter.completion_count == 1, "Remaining inside trigger does not repeat completion")
	await capture("complete")
	# Retry clears the new session's encounter and collection; original saves untouched.
	await key(KEY_R, true)
	await key(KEY_R, false)
	check(not view.encounter.complete and not view.collectible.collected and view.collectible.mesh.visible, "Retry restores objective and sample")
	check(view.enemy_mesh.visible and view.enemy.global_position.is_equal_approx(view.enemy_spawn), "Retry restores actor and spawn")
	# Force an almost-complete enemy windup nearby to verify death and input lock.
	view.enemy.global_position = view.player.global_position + Vector3(0, -33, 25)
	view.encounter.phase = State.Phase.WINDUP
	view.encounter.phase_remaining = 0.001
	view.encounter.player_health = 1
	await physics_frame
	await tick()
	check(view.encounter.player_health == 0, "Enemy impact can defeat player in scene")
	check(view.animation.frame_index == 12, "Fatal impact displays native event frame in same tick")
	var death_position: Vector3 = view.player.global_position
	await key(KEY_W, true)
	await click()
	await tick(15)
	await key(KEY_W, false)
	check(view.player.global_position.is_equal_approx(death_position) and view.encounter.enemy_health == 24, "Defeated player cannot move or strike")
	await capture("player_defeated")
	await key(KEY_R, true)
	await key(KEY_R, false)
	check(view.encounter.player_health == 30, "Retry recovers from player defeat")
	var report := {"checks": checks, "failures": failures, "completion_via_physical_input": true}
	var file := FileAccess.open(directory.path_join("integration.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("Encounter integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
