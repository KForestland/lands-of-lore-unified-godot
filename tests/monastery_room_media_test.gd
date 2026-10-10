extends SceneTree
const View = preload("res://scripts/lol2/monastery_room_view.gd")
func _initialize(): run.call_deferred()
func run():
	var view = View.new()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.enter_room("MLIB")
	view.play_patch(0,32.0/15.0)
	view.set_process(false)
	await create_timer(0.3).timeout
	assert(view.background.is_playing() and view.voice.playing)
	assert(view.patch.position == Vector2(view.clip.x,view.clip.y))
	assert(view.patch.texture.region == Rect2(0,0,640,324))
	var image: Image = view.patch.texture.atlas.get_image()
	assert(image.get_pixel(0,0).a == 0.0)
	if "--capture-monastery" in OS.get_cmdline_user_args():
		await process_frame
		root.get_texture().get_image().save_png("res://tmp/monastery_room.png")
	view.enter_room("MOFF")
	assert(view.clip.is_empty() and not view.voice.playing and view.patch.texture == null)
	view.play_patch(0)
	assert(view.patch.position == Vector2(120,144))
	assert(view.patch.size == Vector2(228,168))
	view.enter_room("MLIB")
	view.play_patch(0)
	assert(view.clip.frames == 80) # switching rooms must not erase the manifest record
	view.background.stop()
	view.voice.stop()
	view.queue_free()
	await process_frame
	await process_frame
	print("PASS: original monastery background/patch placement, alpha, audio and room switch")
	quit()
