extends SceneTree
const View = preload("res://scripts/lol2/hive_rune_room_view.gd")
func _initialize(): run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
func run():
	var view = View.new()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.show_runes(false,false)
	await create_timer(0.3).timeout
	if not check(view.background.is_playing() and view.patch.texture == null,"Dark room must play without stone overlay"): return
	view.show_runes(true,false)
	await create_timer(0.3).timeout
	if not check(view.background.is_playing() and view.patch.texture != null,"Lit room and stone overlay must play"): return
	if not check(view.patch.position == Vector2(396,184) and view.patch.size == Vector2(64,48),"Source stone overlay coordinates differ"): return
	view.set_time(31.0/15.0)
	if not check(view.last_frame == 1,"Stone loop must wrap its30 source frames"): return
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		root.get_texture().get_image().save_png("res://tmp/hive_rune_room.png")
	view.show_runes(true,true)
	await process_frame
	if not check(view.patch.texture == null and view.clip.is_empty(),"Taken stone must stay absent"): return
	view.show_inscription()
	await create_timer(0.3).timeout
	if not check(view.room == "RUNECL" and view.background.is_playing() and view.patch.texture == null,"Inscription switch left stale media"): return
	view.show_runes(false,false)
	view.show_runes(true,false)
	view.show_inscription()
	await create_timer(0.3).timeout
	if not check(view.background.stream.file.ends_with("RUNECL_.ogv"),"Deferred room switch selected stale background"): return
	view.queue_free()
	await process_frame
	await process_frame
	print("PASS: source rune backgrounds, lit stone overlay/loop/removal and inscription switching")
	quit()
