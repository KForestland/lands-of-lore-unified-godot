extends SceneTree
const Timing = preload("res://scripts/lol2/hive_timing_state.gd")
const Clock = preload("res://scripts/lol2/hive_clock_runtime.gd")
const JungleSave = preload("res://scripts/lol2/jungle_save.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	var clock := {"samples":[8,7,9,8],"cursor":3,"fraction8":127,"fraction16":65500,"status_accum":3932159,"seconds":59}
	var checkpoint: Dictionary = Timing.checkpoint(clock,123456789,15).checkpoint
	var handoff: Dictionary = scene.area_handoff()
	assert(not handoff.quests.has("hive_runtime_timing"))
	handoff.quests.hive_runtime_timing = checkpoint.duplicate(true)
	assert(scene.apply_area_handoff(handoff).is_empty())
	scene.set_physics_process(false)
	assert(scene.runtime_timing_checkpoint == checkpoint)
	var exported: Dictionary = scene.area_handoff()
	exported.quests.hive_runtime_timing.clock.samples[0] = 0
	exported.quests.hive_runtime_timing.executioner_a3 = 0
	assert(scene.runtime_timing_checkpoint == checkpoint)
	var path := "user://tests/hive_timing_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(path).is_empty())
	var baseline: Dictionary = scene.area_handoff().duplicate(true)
	for field in ["clock","phase","executioner_a3"]:
		var invalid := baseline.duplicate(true)
		invalid.quests.hive_runtime_timing.erase(field)
		invalid.inventory.collected = [scene.Save.Shared.Museum.SWORD]
		assert(not scene.apply_area_handoff(invalid).is_empty())
		assert(scene.area_handoff() == baseline)
	var invalid_save: Dictionary = scene.Save.read_save(path).state.duplicate(true)
	invalid_save.quests.hive_runtime_timing.phase = 2485000000
	invalid_save.player.position[0] += 100
	var position_before: Vector3 = scene.player.position
	assert(not scene.apply_save(invalid_save).is_empty())
	assert(scene.player.position == position_before and scene.area_handoff() == baseline)
	var legacy := baseline.duplicate(true);legacy.quests.erase("hive_runtime_timing")
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(scene.runtime_timing_checkpoint.is_empty())
	assert(scene.quickload(path).is_empty())
	scene.set_physics_process(false)
	assert(scene.runtime_timing_checkpoint == checkpoint)
	assert(scene.runtime_timing_checkpoint.executioner_a3 is int)
	assert(scene.runtime_timing_checkpoint.clock.cursor is int)
	assert(Clock.advance_reference_time(clock,16667,checkpoint.phase) == Clock.advance_reference_time(scene.runtime_timing_checkpoint.clock,16667,scene.runtime_timing_checkpoint.phase))
	var jungle_state: Dictionary = scene.Save.read_save(path).state.duplicate(true)
	jungle_state.format = JungleSave.FORMAT
	var jungle_path := path.replace("hive_timing_","jungle_timing_")
	assert(JungleSave.write_save(jungle_path,jungle_state).is_empty())
	var returned := JungleSave.read_save(jungle_path)
	assert(returned.error.is_empty())
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(scene.apply_area_handoff(returned.state).is_empty())
	assert(scene.runtime_timing_checkpoint == checkpoint)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(jungle_path)
	scene.queue_free()
	await process_frame
	print("PASS: Hive A3/clock quicksave/load, jungle transport, legacy omission and rejection before scene mutation")
	quit(0)
