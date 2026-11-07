extends SceneTree
const HOSTS := [["Cave", "res://scenes/lol2/cave_walkthrough.tscn"], ["Museum", "res://scenes/lol2/museum_walkthrough.tscn"], ["Jungle", "res://scenes/lol2/jungle_walkthrough.tscn"], ["Hive", "res://scenes/lol2/hive_review.tscn"]]
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func canonical(area, kind: String) -> String:
	match kind:
		"Cave": return JSON.stringify(area._save_state(), "", true)
		"Museum": return JSON.stringify(area.checkpoint_state(), "", true)
		"Jungle": return JSON.stringify({"inventory": area.inventory_state(), "quests": area.quest_state}, "", true)
		"Hive": return JSON.stringify(area.area_handoff(), "", true)
	return ""
func press(code: Key, ctrl := false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.pressed = down; event.ctrl_pressed = ctrl
		Input.parse_input_event(event); Input.flush_buffered_events()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://capture")
	var feedback = root.get_node("PlaytestFeedback")
	feedback.output_root = "user://capture/reports"
	for entry in HOSTS:
		var kind: String = entry[0]
		var area = load(entry[1]).instantiate()
		if kind == "Museum": area.introduction_state = "complete"
		root.add_child(area); current_scene = area
		for i in 900:
			await process_frame
			if area.get("walkthrough_ready") == null or area.walkthrough_ready: break
		for i in 6: await process_frame
		if kind == "Museum" and is_instance_valid(area.get("introduction")): area.introduction.close()
		await RenderingServer.frame_post_draw
		press(KEY_F10)
		if not check(feedback.active and paused and not feedback.prior_paused, kind + " live unpaused F10 failed"): return
		if not check(feedback.pending.area == kind, kind + " normalized area differs"): return
		var native: Dictionary = feedback.pending.camera.native_position
		var global_at: Array = feedback.pending.camera.position
		var origin: Array = feedback.pending.native_translation
		if not check(is_equal_approx(native.x, global_at[0] - origin[0]) and is_equal_approx(native.h, global_at[1] - origin[1]) and is_equal_approx(native.y, global_at[2] - origin[2]), kind + " camera coordinate spaces inconsistent"): return
		if kind == "Cave" and not check(feedback.pending.render_camera.node == str(area.index_camera.get_path()), "Cave report omitted drawn camera"): return
		press(KEY_ESCAPE)
		if not check(not feedback.active and not paused, kind + " live close failed"): return
		paused = true
		var before := canonical(area, kind)
		press(KEY_F10)
		if not check(feedback.active and paused, kind + " F10 failed"): return
		if not check(feedback.pending.diagnostics.status == "ready" and feedback.pending.diagnostics.area == kind, kind + " diagnostics incomplete"): return
		if not check(not feedback.pending.position.is_empty() and not feedback.pending.camera.is_empty(), kind + " location/camera missing"): return
		if not check(feedback.pending.build == ProjectSettings.get_setting("application/config/version") and feedback.pending.build != "unversioned", "build identity absent"): return
		if not check(canonical(area, kind) == before, kind + " capture changed game state"): return
		feedback.screenshot.save_png("user://capture/" + kind.to_lower() + "_before.png")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://capture/" + kind.to_lower() + "_form.png")
		feedback.note.text = kind + ": test report with real host context"
		press(KEY_ENTER, true)
		if not check(not feedback.active and paused and canonical(area, kind) == before, kind + " save changed state"): return
		if not check(FileAccess.file_exists(feedback.last_saved.path_join("report.json")), kind + " report not persisted"): return
		print("PASS feedback real host: ", kind)
		paused = false
		area.queue_free(); current_scene = null
		for i in 3: await process_frame
	print("PASS all four gameplay hosts: F10/Ctrl+Enter, context, screenshots, pause and canonical state preservation")
	quit(0)
