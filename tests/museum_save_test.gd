extends SceneTree
const Save = preload("res://scripts/lol2/museum_save.gd")
func _initialize() -> void:
	_run.call_deferred()
func make_scene() -> Node3D:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	scene.set_physics_process(false)
	scene.sword_transfer.set_process(false)
	scene.museum_gate.set_physics_process(false)
	return scene
func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--resume-proof="):
			var path := argument.trim_prefix("--resume-proof=")
			var saved := Save.read_save(path)
			assert(saved.error.is_empty())
			assert(not has_meta("lol2_museum_checkpoint"))
			set_meta("lol2_museum_resume",saved.state)
			var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
			root.add_child(scene)
			assert(scene.introduction_state == "complete" and not is_instance_valid(scene.introduction))
			assert(scene.player.position.is_equal_approx(Vector3(-4222,32,-1050)))
			assert(scene.equipped_item == scene.SWORD_ITEM_ID and scene.sword_transfer.collected)
			assert(is_equal_approx(scene.museum_gate.progress,0.5))
			assert(scene.interface_hud.weapon_icon.visible and not scene.interface_hud.cursor_active)
			assert(not has_meta("lol2_museum_resume"))
			scene.free()
			DirAccess.remove_absolute(path)
			print("Fresh-process museum resume passed: saved position, equipment, gate, intro suppression")
			quit()
			return
	var path := "user://tests/museum_save_%d.json" % Time.get_ticks_usec()
	var scene := make_scene()
	scene.sword_transfer.restart()
	scene.sword_transfer.advance(7.8)
	scene.museum_gate.advance(0.6)
	scene.carried_collected = [Save.SWORD,Save.CAVERN]
	scene.sword_transfer.collect()
	assert(scene.set_equipped_item(Save.SWORD))
	scene.player.position = Vector3(-4222,32,-1050)
	scene.player.rotation.y = 0.3
	scene.camera.rotation.x = -0.2
	assert(scene.quicksave(path).is_empty())
	var saved := Save.read_save(path)
	assert(saved.error.is_empty())
	var previous := FileAccess.get_file_as_bytes(path)
	for invalid in [null,{},[], {"format": Save.FORMAT,"version":true}]:
		assert(not Save.validate(invalid).is_empty())
	for key in ["collected","sword","gate","equipped_item"]:
		var invalid: Dictionary = saved.state.duplicate(true)
		invalid.checkpoint[key] = null
		assert(not Save.write_save(path,invalid).is_empty())
		assert(FileAccess.get_file_as_bytes(path) == previous)
	for ids in [[Save.SWORD,Save.SWORD],[],["unknown"]]:
		var invalid: Dictionary = saved.state.duplicate(true)
		invalid.checkpoint.collected = ids
		assert(not Save.validate(invalid).is_empty())
	var invalid: Dictionary = saved.state.duplicate(true)
	invalid.player.pitch = NAN
	assert(not Save.validate(invalid).is_empty())
	invalid = saved.state.duplicate(true)
	invalid.checkpoint.sword.elapsed = INF
	assert(not Save.validate(invalid).is_empty())
	scene.player.position = Vector3.ZERO
	scene.set_equipped_item("")
	scene.sword_transfer.restart()
	assert(scene.quickload(path).is_empty())
	assert(scene.player.position.is_equal_approx(Vector3(-4222,32,-1050)))
	assert(scene.equipped_item == Save.SWORD and scene.sword_transfer.collected)
	assert(is_equal_approx(scene.museum_gate.progress,0.5))
	assert(is_equal_approx(scene.camera.rotation.x,-0.2))
	for broken in ["{", " ".repeat(Save.MAX_BYTES+1)]:
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(broken)
		file.close()
		assert(not scene.quickload(path).is_empty())
		assert(scene.equipped_item == Save.SWORD)
		assert(scene.player.position.is_equal_approx(Vector3(-4222,32,-1050)))
	assert(Save.write_save(path,saved.state).is_empty())
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	print("Museum save passed: roundtrip, equipment, gate, invalid state rejection, previous-file preservation and damaged-load isolation")
	print("RESTART_PATH=" + path)
	quit()
