extends SceneTree
const Schedule = preload("res://scripts/lol2/hive_ai_schedule.gd")
const JungleSave = preload("res://scripts/lol2/jungle_save.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	var rows := []
	for i in range(40): rows.append({"allocated":false})
	rows[36] = {"allocated":true,"a8":6,"b5":0,"actor70":3,"region_present":true,"region_flags":4,"object_flags":0}
	var first := Schedule.next_action(Schedule.begin(40,[35,12]).state,rows)
	assert(first.action.index == 36 and first.action.pass == 0)
	rows[36].b5 = first.action.set_b5
	var checkpoint: Dictionary = first.state
	var handoff: Dictionary = scene.area_handoff()
	assert(not handoff.quests.has("hive_runtime_schedule"))
	handoff.quests.hive_runtime_schedule = checkpoint.duplicate(true)
	assert(scene.apply_area_handoff(handoff).is_empty())
	scene.set_physics_process(false)
	assert(scene.runtime_schedule_checkpoint == checkpoint)
	var exported: Dictionary = scene.area_handoff()
	exported.quests.hive_runtime_schedule.cursors[0] = 0
	assert(scene.runtime_schedule_checkpoint == checkpoint)
	var path := "user://tests/hive_schedule_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(path).is_empty())
	var baseline: Dictionary = scene.area_handoff().duplicate(true)
	for field in ["capacity","cursors","pass","scanned","disabled","version"]:
		var invalid := baseline.duplicate(true)
		invalid.quests.hive_runtime_schedule.erase(field)
		invalid.inventory.collected = [scene.Save.Shared.Museum.SWORD]
		assert(not scene.apply_area_handoff(invalid).is_empty())
		assert(scene.area_handoff() == baseline)
	var invalid_save: Dictionary = scene.Save.read_save(path).state.duplicate(true)
	invalid_save.quests.hive_runtime_schedule.cursors[0] = 40
	invalid_save.player.position[0] += 100
	var position_before: Vector3 = scene.player.position
	assert(not scene.apply_save(invalid_save).is_empty())
	assert(scene.player.position == position_before and scene.area_handoff() == baseline)
	var legacy := baseline.duplicate(true);legacy.quests.erase("hive_runtime_schedule")
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(scene.runtime_schedule_checkpoint.is_empty())
	assert(scene.quickload(path).is_empty())
	scene.set_physics_process(false)
	assert(scene.runtime_schedule_checkpoint == checkpoint)
	assert(scene.runtime_schedule_checkpoint.cursors[0] is int)
	# The first-pass decision is already applied; loading must not select it again.
	assert(Schedule.next_action(scene.runtime_schedule_checkpoint,rows) == Schedule.next_action(checkpoint,rows))
	assert(Schedule.next_action(scene.runtime_schedule_checkpoint,rows).done)
	var jungle_state: Dictionary = scene.Save.read_save(path).state.duplicate(true)
	jungle_state.format = JungleSave.FORMAT
	var jungle_path := path.replace("hive_schedule_","jungle_schedule_")
	assert(JungleSave.write_save(jungle_path,jungle_state).is_empty())
	var returned := JungleSave.read_save(jungle_path)
	assert(returned.error.is_empty())
	assert(scene.apply_area_handoff(legacy).is_empty())
	assert(scene.apply_area_handoff(returned.state).is_empty())
	assert(scene.runtime_schedule_checkpoint == checkpoint)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(jungle_path)
	scene.queue_free()
	await process_frame
	print("PASS: Hive scheduler save/load, continuation without repeat decision, jungle transport and atomic rejection")
	quit(0)
