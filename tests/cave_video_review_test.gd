extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/cave_video_review.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.5).timeout
	assert(scene.video.is_playing())
	scene.toggle_pause()
	assert(scene.video.paused)
	var position: float = scene.video.stream_position
	await create_timer(0.3).timeout
	assert(absf(scene.video.stream_position - position) < 0.01)
	scene.play_clip(1)
	assert(not scene.video.paused and scene.video.is_playing())
	await create_timer(0.5).timeout
	assert(scene.video.stream_position > 0)
	if "--capture-video-review" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("/home/bob/lol2_out/cave_video_review_20260913/godot_review.png") == OK)
	scene.play_clip(2)
	for i in range(80):
		await create_timer(0.1).timeout
		if scene.status.text.begins_with("Finished"): break
	assert(scene.status.text.begins_with("Finished"), "Real playback must finish")
	scene.toggle_pause()
	assert(scene.video.is_playing() and not scene.video.paused)
	scene.play_clip(-1)
	assert(scene.selected == scene.CLIPS.size()-1)
	scene.play_clip(scene.CLIPS.size())
	assert(scene.selected == 0)
	print("Video review passed: real playback, pause holds time, switch clears pause, finish, replay and wrap")
	scene.free()
	quit()
