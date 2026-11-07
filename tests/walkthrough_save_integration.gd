extends SceneTree

const Save = preload("res://scripts/lol2/walkthrough_save.gd")
const SCENE := "res://scenes/lol2/cave_walkthrough.tscn"
var view: Node
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error(description)
		failures += 1
	checks += 1

func open_cave() -> void:
	view = load(SCENE).instantiate()
	root.add_child(view)
	for frame in range(120):
		await process_frame
		if view.walkthrough_ready:
			break
	check(view.walkthrough_ready, "Cavern initialized")
	view.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _run() -> void:
	# The test runner creates a project with a distinct application name.
	check(OS.get_user_data_dir().get_file().begins_with("LoL2 Save Integration Test"), "Test user data must be isolated")
	if failures:
		quit(1)
		return
	await open_cave()
	if "--restart-read" in OS.get_cmdline_user_args():
		check(view.checkpoint == view.fixtures[0].checkpoints.size()+1, "New process starts at source cave entrance")
		await press(KEY_F9)
		check(view.checkpoint == 118 and view.flying, "New process restores checkpoint and flight")
		var position: Vector3 = view.point(view.fixtures[0].checkpoints[118].start) + Vector3(0.5, 134, 0.75)
		check(view.player.position.is_equal_approx(position), "New process restores position")
		check(is_equal_approx(view.player.rotation.y, 1.25) and view.camera.rotation.is_equal_approx(Vector3(-0.37, 0, 0)), "New process restores view direction")
		check(not view.lighting_enabled and not view.glows_enabled and not view.props_root.visible and not view.roof.visible and not view.dummy_root.visible, "New process restores display toggles")
		DirAccess.remove_absolute(Save.DEFAULT_PATH)
		print("Restart read: %d checks, %d failures" % [checks, failures])
		quit(1 if failures else 0)
		return
	view._jump_checkpoint(118)
	view.player.position += Vector3(0.5, 100, 0.75)
	view.player.rotation.y = 1.25
	view.camera.rotation = Vector3(-0.37, 0, 0)
	view.flying = true
	view._set_lighting(false)
	view.glows_enabled = false
	view.props_root.visible = false
	view.roof.visible = false
	view.dummy_root.visible = false
	var expected: Dictionary = view._save_state()
	await press(KEY_F5)
	check(FileAccess.file_exists(Save.DEFAULT_PATH), "F5 writes quicksave")
	check(view.save_notice == "Quicksaved.", "Save feedback")
	if "--restart-write" in OS.get_cmdline_user_args():
		print("Restart write: %d checks, %d failures" % [checks, failures])
		quit(1 if failures else 0)
		return
	view._jump_checkpoint(13)
	view._set_lighting(true)
	view.glows_enabled = true
	view.props_root.visible = true
	view.roof.visible = true
	view.dummy_root.visible = true
	view.player.velocity = Vector3(10, -99, 20)
	await press(KEY_F9)
	check(view._save_state() == expected, "F9 restores all state")
	check(view.player.velocity == Vector3.ZERO, "Load clears stale velocity")
	check(view.light_view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Reference lighting restored")
	check(view.light_pairs.all(func(pair): return pair[1].visible == pair[0].is_visible_in_tree()), "Light masks synchronized")
	check(view.occluder_pairs.all(func(pair): return pair[1].visible == pair[0].is_visible_in_tree()), "Special masks synchronized")
	view.queue_free()
	await process_frame
	await open_cave()
	await press(KEY_F9)
	check(view._save_state() == expected, "New scene restores disk save")
	var before: Dictionary = view._save_state()
	var file := FileAccess.open(Save.DEFAULT_PATH, FileAccess.WRITE)
	file.store_string("{\"version\":999}")
	file.close()
	await press(KEY_F9)
	check(view._save_state() == before, "Rejected save leaves live state unchanged")
	check(view.save_notice.begins_with("Load failed:"), "Load failure feedback")
	await press(KEY_R)
	check(view.checkpoint == 118 and view.player.position.is_equal_approx(view.start + Vector3.UP * 34), "R uses restored checkpoint anchor")
	check(not view.flying, "Reset returns to walking")
	# Also persist ordinary walking with all visual options enabled.
	view._jump_checkpoint(13)
	view._set_lighting(true)
	view.glows_enabled = true
	view.props_root.visible = true
	view.roof.visible = true
	view.dummy_root.visible = true
	expected = view._save_state()
	await press(KEY_F5)
	view._jump_checkpoint(118)
	await press(KEY_F9)
	check(view._save_state() == expected, "Walking/enhanced state round trip")
	check(view.light_view.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Enhanced light pass restored")
	DirAccess.remove_absolute(Save.DEFAULT_PATH)
	print("Cavern save/load integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
