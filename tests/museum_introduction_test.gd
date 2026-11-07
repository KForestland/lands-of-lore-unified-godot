extends SceneTree
## Museum arrival and Draracle pedestal videos (docs/museum-draracle-videos.md): source arrival heading, no automatic
## clip, region1220 grounded entry plays e032e then e033e (local19 0 -> 1 -> 2) with the op18 return pose, an
## interrupted clip keeps local19, saves validate the field and legacy checkpoints count as both clips played.
const Draracle = preload("res://scripts/lol2/museum_draracle.gd")
const Save = preload("res://scripts/lol2/museum_save.gd")
func _initialize() -> void:
	_run.call_deferred()

func make_scene() -> Node3D:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	scene.sword_transfer.set_process(false)
	scene.museum_gate.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in range(30):
		await physics_frame
		scene.player.velocity = Vector3(0,-80,0)
		scene.player.move_and_slide()
	return scene

## Walks east (owner report 11:08 direction) with the capsule until the host entry check starts a clip.
func walk_east(scene: Node3D, frames: int) -> bool:
	for i in range(frames):
		await physics_frame
		scene.player.velocity = Vector3(80,-1 if scene.player.is_on_floor() else scene.player.velocity.y-320.0/60,0)
		scene.player.move_and_slide()
		scene.check_draracle_entry()
		if scene.introduction_state == "playing": return true
	return false

func _run() -> void:
	var src := Draracle.source()
	assert(src.steps.size() == 2 and src.steps[0].clip == 4 and src.steps[1].clip == 5)
	var scene = await make_scene()
	# Source arrival: index1 heading 49152 -> yaw +PI/2, control at once, nothing playing.
	assert(is_equal_approx(scene.player.rotation.y, PI/2) and scene.player.position.x == -3796.0 and scene.player.position.z == -369.0)
	assert(scene.introduction_state == "complete" and not is_instance_valid(scene.introduction) and not paused)
	assert(scene.draracle_local19 == 0 and not scene.start_introduction(), "No clip outside region1220")
	# First entry: e032e, then local19 1 and the op18 return pose.
	assert(await walk_east(scene, 240), "Walking onto the pedestal starts the first clip")
	assert(paused and scene.introduction.review.selected == 4 and scene.player.position.x > -3718.5)
	scene.introduction._story_finished()
	for i in range(3): await process_frame
	assert(scene.introduction_state == "complete" and not paused and scene.draracle_local19 == 1)
	assert(scene.player.position.x == -3751.0 and scene.player.position.z == -371.0 and is_equal_approx(scene.player.rotation.y, PI/2))
	assert(not scene.start_introduction(), "Return pose is outside region1220")
	# Second entry: e033e (skipped counts like the native one-way movie), local19 2.
	assert(await walk_east(scene, 240))
	assert(paused and scene.introduction.review.selected == 5)
	scene.introduction.close()
	for i in range(3): await process_frame
	assert(scene.introduction_state == "complete" and not paused and scene.draracle_local19 == 2)
	assert(scene.player.position.x == -3753.0 and scene.player.position.z == -373.0)
	# Third entry: no source record admits local19 2.
	assert(not await walk_east(scene, 50), "No third clip")
	assert(scene.player.position.x > -3718.0 and Draracle.inside(src, scene.player.position, scene.player.position.y - 32.0))
	var saved: Dictionary = scene.capture_exhibit_retry()
	assert(saved.checkpoint.museum_draracle == {"local19": 2} and Save.validate(saved).is_empty())
	scene.free()
	# Interrupted clip keeps local19; leaving and re-entering plays it again. Checkpoint carries local19.
	scene = await make_scene()
	assert(scene.draracle_local19 == 2, "Session checkpoint restores local19")
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	scene = await make_scene()
	assert(scene.draracle_local19 == 0)
	assert(await walk_east(scene, 240))
	scene.introduction.queue_free()
	for i in range(3): await process_frame
	assert(scene.introduction_state == "complete" and not paused and scene.draracle_local19 == 0)
	assert(not await walk_east(scene, 30), "Standing inside is not a new entry")
	scene.player.position = Vector3(-3751, scene.player.position.y, -371)
	scene.check_draracle_entry()
	assert(await walk_east(scene, 240) and scene.introduction.review.selected == 4)
	scene.introduction._story_finished()
	for i in range(3): await process_frame
	assert(scene.draracle_local19 == 1)
	# Save validation and legacy restoration.
	var state: Dictionary = scene.capture_exhibit_retry()
	for bad in [{"local19": 4}, {"local19": -1}, {"local19": 1.5}, {"local19": "1"}, {}, {"local19": 1, "x": 0}, []]:
		var copy: Dictionary = state.duplicate(true)
		copy.checkpoint.museum_draracle = bad
		assert(not Save.validate(copy).is_empty(), str(bad))
	var legacy: Dictionary = state.duplicate(true)
	legacy.checkpoint.erase("museum_draracle")
	assert(Save.validate(legacy).is_empty())
	scene.apply_save(legacy)
	assert(scene.draracle_local19 == 2, "Legacy saves already played both clips")
	scene.apply_save(state)
	assert(scene.draracle_local19 == 1)
	assert(Draracle.restore(null) == 2 and Draracle.restore({"local19": 0}) == 0)
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	print("Museum introduction passed: arrival heading 49152, no automatic clip, region1220 e032e/e033e with return pose, interrupt keeps local19, no third clip, save/legacy validation")
	quit()
