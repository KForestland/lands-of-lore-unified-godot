extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	scene.introduction_state = "complete"
	root.add_child(scene)
	var hud = scene.interface_hud
	hud.set_process(false)
	assert(not hud.blink.visible and hud.blink_textures.size() == 3)
	hud.advance_blink(4.55)
	assert(hud.blink.visible and hud.blink.texture == hud.blink_textures[0])
	hud.advance_blink(0.1)
	assert(hud.blink.texture == hud.blink_textures[1])
	paused = true
	var elapsed: float = hud.blink_elapsed
	hud._process(1.0)
	assert(hud.blink_elapsed == elapsed)
	paused = false
	if "--capture-portrait" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/home/bob/lol2_out/museum_sword_transfer_review_20260914/godot_portrait_blink.png")
	hud.advance_blink(0.1)
	assert(hud.blink.texture == hud.blink_textures[2])
	hud.advance_blink(0.1)
	assert(not hud.blink.visible)
	hud.advance_blink(48.0)
	assert(not hud.blink.visible)
	scene.free()
	remove_meta("lol2_museum_checkpoint")
	print("Portrait blink passed: neutral, three source eye frames, pause, return to neutral, long-step wrap")
	quit()
