extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	for i in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	assert(scene.walkthrough_ready)
	scene.set_physics_process(false)
	scene.set_process_unhandled_input(false)
	var position: Vector3 = scene.player.position
	var path := "user://tests/forms_%d.json" % Time.get_ticks_usec()
	# Source trigger admission is separate; this fixture checks physical/save state.
	for form in range(3):
		scene.player_form = form
		assert(scene.FormBody.apply(scene.player,scene.camera,form,false))
		assert(scene._quicksave(path).is_empty())
		scene.player_form = (form+1)%3
		scene.FormBody.apply(scene.player,scene.camera,scene.player_form,false)
		assert(scene._quickload(path).is_empty())
		assert(scene.player_form == form)
		assert(scene.player.position == position)
		assert(scene.player.get_child(0).shape.height == scene.FormBody.HEIGHTS[form])
		assert(scene.camera.position.y == scene.FormBody.EYES[form]-32)
	var state: Dictionary = scene._save_state()
	state.player_form = 0.5
	assert(not scene.WalkthroughSave.validate(state,scene._checkpoint_count()).is_empty())
	state.erase("player_form")
	assert(scene.WalkthroughSave.write_save(path,state,scene._checkpoint_count()).is_empty())
	assert(scene._quickload(path).is_empty())
	assert(scene.player_form == 0 and scene.player.position == position)
	DirAccess.remove_absolute(path)
	scene.free()
	print("PASS cave form disk saves: all three shapes/cameras, stable feet, malformed rejection and legacy human restore")
	quit()
