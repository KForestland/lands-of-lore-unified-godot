extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in range(240):
		await process_frame
		if scene.walkthrough_ready: break
	for i in range(3): await physics_frame
	assert(scene.chamber_arrival_state == "not_started", "No unverified automatic trigger")
	scene.collectible.collected = true
	assert(scene.play_chamber_arrival())
	assert(not scene.play_chamber_arrival())
	assert(paused and scene.video_overlay.review.selected == 0)
	assert(not scene.video_overlay.review.picker.visible)
	await create_timer(0.5).timeout
	assert(scene.video_overlay.review.video.stream_position > 0)
	if "--chamber-finish" in OS.get_cmdline_user_args():
		var discussion_seen := false
		var captured := false
		for i in range(1500):
			await create_timer(0.1).timeout
			if not is_instance_valid(scene): break
			assert(paused)
			if scene.video_overlay.review.selected == 3:
				discussion_seen = true
				if scene.video_overlay.review.video.stream_position > 6.0 and not captured:
					await RenderingServer.frame_post_draw
					assert(root.get_texture().get_image().save_png("/home/bob/lol2_out/chamber_sequence_20260913/discussion.png") == OK)
					captured = true
		assert(discussion_seen and captured)
		for i in range(5): await process_frame
		assert(not is_instance_valid(scene))
		assert(current_scene.introduction_state == "playing" and paused)
		assert(current_scene.introduction.review.selected == 4)
		print("Full cave playlist passed and handed off to museum introduction")
		current_scene.free()
		quit()
		return
	scene.video_overlay._story_finished()
	assert(scene.video_overlay.review.selected == 3 and paused)
	scene.video_overlay.queue_free()
	await process_frame
	await process_frame
	assert(not paused and scene.chamber_arrival_state == "not_started")
	assert(scene.play_chamber_arrival())
	scene.video_overlay._story_finished()
	assert(scene.video_overlay.review.selected == 3 and paused)
	scene.video_overlay.review.close()
	await process_frame
	await process_frame
	for i in range(5): await process_frame
	assert(not is_instance_valid(scene))
	var museum = current_scene
	assert(museum.carried_collected == ["draracle/prop/1108/sample"])
	assert(museum.introduction_state == "playing" and paused)
	assert(museum.introduction.review.selected == 4)
	assert(not museum.start_introduction())
	await create_timer(0.5).timeout
	assert(museum.introduction.review.video.stream_position > 0)
	museum.introduction._story_finished()
	assert(museum.introduction.review.selected == 5 and paused)
	museum.introduction.review.close()
	for i in range(3): await process_frame
	assert(museum.introduction_state == "complete" and not paused)
	assert(not museum.start_introduction())
	for i in range(120): await physics_frame
	assert(museum.player.is_on_floor())
	print("Chamber handoff passed: interruption/retry, skip, old scene freed, museum clip order, duplicate prevention and floor support")
	museum.free()
	quit()
