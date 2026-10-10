extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var Overlay = load("res://scripts/lol2/cave_video_overlay.gd")
	assert(not Overlay.story_assets_ready([]))
	assert(not Overlay.story_assets_ready([-1]))
	assert(not Overlay.story_assets_ready([999]))
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	assert(paused and scene.introduction.review.selected == 4)
	var start: Vector3 = scene.player.position
	await create_timer(0.5).timeout
	scene.introduction.review.toggle_pause()
	assert(scene.introduction.review.video.paused)
	# Let the queued decoder/audio frame settle before measuring held time.
	await create_timer(0.15).timeout
	var position: float = scene.introduction.review.video.stream_position
	await create_timer(0.3).timeout
	assert(absf(scene.introduction.review.video.stream_position - position) < 0.01)
	scene.introduction.review.toggle_pause()
	var second_seen := false
	for i in range(850):
		await create_timer(0.1).timeout
		if scene.introduction_state == "complete": break
		assert(paused and scene.player.position == start)
		if scene.introduction.review.selected == 5: second_seen = true
	assert(second_seen and scene.introduction_state == "complete")
	assert(not paused and not scene.start_introduction())
	for i in range(90): await physics_frame
	assert(scene.player.is_on_floor())
	print("Museum introduction passed: natural two-clip completion, pause, frozen world, no repeat and floor support")
	scene.free()
	quit()
