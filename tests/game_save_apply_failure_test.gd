extends SceneTree
## Supplied packet + Cave configuration injection; no earned-walk claim.
const Save = preload("res://scripts/lol2/game_save.gd")
const Session = preload("res://scripts/lol2/game_session.gd")
const Cases = preload("res://tests/helpers/game_save_cases.gd")
func _initialize() -> void: run.call_deferred()
func no_cave_combat(node: Node) -> void:
	if node.scene_file_path == Save.Areas.ROWS.L1_DC.scene:
		node.source_combat_enabled = false
		# A late scene-exit cache writer must not overwrite the recovered metadata.
		node.tree_exiting.connect(func(): set_meta("lol2_museum_checkpoint", {"failed_cache":true}))
func run() -> void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE") == "1")
	assert("--no-autosave" not in OS.get_cmdline_user_args(), "test must exercise autosave")
	assert(DisplayServer.get_name() != "headless")
	var session: Node = Session.for_tree(self)
	session.set_process(false) # Drive the real scheduler explicitly, with ordinary admission.
	var live = load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
	root.add_child(live); current_scene = live
	for i in 1500:
		await process_frame
		if live.ready_for_review: break
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 30: await physics_frame
	assert(live.can_save().is_empty(), live.can_save())
	live.process_mode = Node.PROCESS_MODE_DISABLED # Keep exact outgoing state for the rollback comparison.
	assert(Save.save(live,3).is_empty())
	session.play_seconds = 17.25
	set_meta("lol2_museum_checkpoint", {"prior_cache":true})
	var prior: Dictionary = session.runtime_checkpoint()
	var before: Dictionary = live.area_snapshot()
	var camera_before: Transform3D = live.camera.global_transform
	var doc := Cases.document("L1_DC")
	assert(doc.area_save.has("roach"), "actual incompatible Cave packet")
	assert(Save.write_document(Save.slot_path(4),doc).is_empty())
	node_added.connect(no_cave_combat)
	assert(Save.load(self,4).is_empty(), "validated packet reaches apply")
	await scene_changed
	for i in 1800:
		await process_frame
		if current_scene == live and not session.changing_scene: break
	node_added.disconnect(no_cave_combat)
	assert(current_scene == live and live.is_inside_tree(), "same previous scene restored")
	assert(session.pending_resume.is_empty() and not session.changing_scene and not has_meta("lol2_slot_resume"), "all load locks released")
	assert(session.runtime_checkpoint() == prior, "previous bank, options, time and slot restored")
	assert(get_meta("lol2_museum_checkpoint") == {"prior_cache":true}, "previous metadata restored")
	assert(live.area_snapshot() == before and live.camera.global_transform == camera_before, "previous player and world unchanged")
	live.process_mode = Node.PROCESS_MODE_INHERIT
	for i in 3: await physics_frame
	assert(live.can_save().is_empty(), live.can_save())
	assert(Save.save(live,3).is_empty(), "ordinary save usable after failed apply")
	assert(Save.read_document(Save.slot_path(3)).state.area_save.inventory == JSON.parse_string(JSON.stringify(live.area_snapshot().inventory)))
	var writes: int = session.autosave_writes
	session.advance_play(0.0)
	for i in 3: await physics_frame
	session.advance_play(601.0)
	assert(session.save_in_progress(), "scheduler admits restored host: "+live.can_save())
	for i in 3000:
		await process_frame
		session.advance_play(0.0)
		if not session.save_in_progress(): break
	assert(session.autosave_writes == writes+1 and session.last_autosave_error.is_empty(), "scheduler writes after failed apply")
	assert(Save.load(self,4).is_empty(), "subsequent load admitted")
	await scene_changed
	for i in 1800:
		await process_frame
		if session.pending_resume.is_empty() and not session.changing_scene: break
	assert(current_scene != live and session.pending_resume.is_empty() and not session.changing_scene, "retry applies with normal Cave combat")
	assert(not is_instance_valid(live), "successful retry releases retained scene")
	assert(current_scene.roach != null and JSON.parse_string(JSON.stringify(current_scene.area_snapshot().roach)) == doc.area_save.roach)
	current_scene.free(); current_scene = null
	print("PASS failed Cave apply restores previous scene/session, releases every lock, saves/autosaves and retries successfully")
	quit()
