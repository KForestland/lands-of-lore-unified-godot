extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/magic_shop/room.json"))
	var view = load("res://scripts/lol2/monastery_room_view.gd").new()
	root.add_child(view)
	view.size = Vector2(1280,720)
	view.set_process(false)
	var clips: Array = []
	for line in data.lines: clips.append(data.lines[line])
	view.manifest.rooms.MAGIC = {"background":data.background,"idle":data.idle,"movies":clips}
	view.enter_room("MAGIC")
	await process_frame
	await RenderingServer.frame_post_draw
	assert(view.background.is_playing())
	for index in range(clips.size()):
		var clip: Dictionary = clips[index]
		view.play_patch(index)
		assert(view.patch.position == Vector2(clip.x,clip.y))
		assert(view.patch.size == Vector2(clip.width,clip.height))
		assert(view.voice.playing and absf(view.voice.stream.get_length()-float(clip.audio_samples)/22050.0)<0.001)
		await RenderingServer.frame_post_draw
		view.set_time(float(clip.duration)*0.5)
		await RenderingServer.frame_post_draw
		assert(view.patch.texture.region.size == Vector2(clip.width,clip.height))
		view.set_time(float(clip.duration))
		assert(view.last_frame == int(clip.frames)-1)
	view.play_idle()
	await RenderingServer.frame_post_draw
	assert(not view.voice.playing and view.clip.idle)
	root.get_texture().get_image().save_png("res://tmp/magic_shop_idle.png")
	view.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	print("PASS: original Rashar background, idle and30 dialogue patch/audio resources render and seek")
	quit()
