extends SceneTree
const Markers = preload("res://scripts/lol2/hive_marker_runtime.gd")
const JungleSave = preload("res://scripts/lol2/jungle_save.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	var loaded := Markers.load_hive_executioner()
	assert(not loaded.has("error"))
	var checkpoint: Dictionary = Markers.checkpoint(loaded.bank,7,9,1234).checkpoint
	var handoff: Dictionary = scene.area_handoff()
	assert(not handoff.quests.has("hive_executioner_markers"))
	handoff.quests.hive_executioner_markers = checkpoint.duplicate(true)
	assert(scene.apply_area_handoff(handoff).is_empty())
	scene.set_physics_process(false)
	assert(scene.executioner_marker_checkpoint == checkpoint)
	# Returned handoff state cannot alias live scene state.
	var exported: Dictionary = scene.area_handoff()
	exported.quests.hive_executioner_markers.selected = 12
	assert(scene.executioner_marker_checkpoint.selected == 9)
	var path := "user://tests/hive_markers_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(path).is_empty())
	var baseline: Dictionary = scene.area_handoff().duplicate(true)
	for field in ["selected","bank_sha256"]:
		var invalid := baseline.duplicate(true)
		invalid.quests.hive_executioner_markers.erase(field)
		invalid.inventory.collected = [scene.Save.Shared.Museum.SWORD]
		assert(not scene.apply_area_handoff(invalid).is_empty())
		assert(scene.area_handoff() == baseline)
	var invalid_save: Dictionary = scene.Save.read_save(path).state.duplicate(true)
	invalid_save.quests.hive_executioner_markers.actor_marker = 60
	invalid_save.player.position[0] += 100
	var position_before: Vector3 = scene.player.position
	assert(not scene.apply_save(invalid_save).is_empty())
	assert(scene.player.position == position_before and scene.area_handoff() == baseline)
	# Legacy saves leave runtime initialization pending, clearing stale state.
	var legacy := baseline.duplicate(true);legacy.quests.erase("hive_executioner_markers")
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(scene.executioner_marker_checkpoint.is_empty())
	assert(scene.quickload(path).is_empty())
	scene.set_physics_process(false)
	assert(scene.executioner_marker_checkpoint == checkpoint)
	# Exercise the shared quest transport through a real jungle save file.
	var jungle_state: Dictionary = scene.Save.read_save(path).state.duplicate(true)
	jungle_state.format = JungleSave.FORMAT
	var jungle_path := path.replace("hive_markers_","jungle_markers_")
	assert(JungleSave.write_save(jungle_path,jungle_state).is_empty())
	var returned := JungleSave.read_save(jungle_path)
	assert(returned.error.is_empty())
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(scene.apply_area_handoff(returned.state).is_empty())
	assert(scene.executioner_marker_checkpoint == checkpoint)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(jungle_path)
	scene.queue_free()
	await process_frame
	print("PASS: Hive marker scene quicksave/load, jungle save transport, legacy omission and atomic invalid-state rejection")
	quit(0)
