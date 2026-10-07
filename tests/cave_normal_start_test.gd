extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(not "--chain-approach" in OS.get_cmdline_user_args())
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave)
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready: break
	assert(cave.walkthrough_ready)
	assert(cave.indexed_chain != null and cave.indexed_doors.size() == 2)
	assert(cave.river_deck != null and cave.river_chains != null and cave.bridge_warning != null)
	assert(cave.river_deck.sections.size() == 6)
	var position: Vector3 = cave.player.global_position-cave.native_translation
	assert(Vector2(position.x,position.z).distance_to(Vector2(-953,-4302)) < 0.01)
	assert(cave.checkpoint == 120 and cave._checkpoint_count() == 121)
	for i in range(90): await physics_frame
	assert(cave.player.is_on_floor() and cave.resets == 0)
	position = cave.player.global_position-cave.native_translation
	assert(absf(position.y-62.05)<0.2,"Source arrival stands on floor30 with fixed32-unit feet offset")
	cave.set_physics_process(false)
	var path := "user://tests/start_%d.json" % Time.get_ticks_usec()
	assert(cave._quicksave(path).is_empty())
	var saved: Dictionary = cave._save_state()
	assert(saved.has("bridge") and saved.has("chain_doors"))
	cave._jump_checkpoint(13)
	assert(cave._quickload(path).is_empty())
	assert(cave._save_state() == saved)
	cave.player.global_position += Vector3(100,100,100)
	cave._reset()
	position = cave.player.global_position-cave.native_translation
	assert(position.is_equal_approx(Vector3(-953,64,-4302)))
	# Existing checkpoint IDs retain their original anchors and can still load.
	cave._jump_checkpoint(13)
	var legacy: Dictionary = cave._save_state()
	legacy.erase("bridge")
	legacy.erase("chain_doors")
	assert(cave.WalkthroughSave.write_save(path,legacy,cave._checkpoint_count()).is_empty())
	cave._jump_checkpoint(120)
	assert(cave._quickload(path).is_empty())
	assert(cave.checkpoint == 13 and cave.player.position == cave.point(legacy.player.position))
	DirAccess.remove_absolute(path)
	cave.free()
	print("PASS normal cave startup: source entrance grounding, complete bridge/door controllers, entrance save/reset and legacy checkpoint load")
	quit()
