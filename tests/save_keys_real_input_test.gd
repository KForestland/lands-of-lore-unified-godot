extends "res://tests/game_save_quit_load_test.gd"
## One local area, real keys/clicks and live physics. No resource or pose edits.
const Save=preload("res://scripts/lol2/game_save.gd")
func click_button(button: Button) -> void:
	assert(button.is_visible_in_tree() and not button.disabled,"visible available button "+button.name)
	await process_frame
	var point:=button.get_global_rect().get_center()
	Input.warp_mouse(point)
	var motion:=InputEventMouseMotion.new();motion.position=point;motion.global_position=point
	Input.parse_input_event(motion);Input.flush_buffered_events();await process_frame
	for down in [true,false]:
		var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=point;e.global_position=point
		Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
func walk_a_bit() -> void:
	await process_frame
	var e:=InputEventKey.new();e.keycode=KEY_W;e.physical_keycode=KEY_W;e.pressed=true
	Input.parse_input_event(e);Input.flush_buffered_events();await ticks(12)
	e=InputEventKey.new();e.keycode=KEY_W;e.physical_keycode=KEY_W;e.pressed=false
	Input.parse_input_event(e);Input.flush_buffered_events();await ticks(3)
func reload_finished(previous: int) -> void:
	if current_scene!=null and current_scene.get_instance_id()==previous:await scene_changed
	scene=current_scene;await settled()
func run() -> void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE")=="1")
	scene=load("res://scenes/lol2/maps/L10_DC.tscn").instantiate();root.add_child(scene);current_scene=scene;await settled()
	await tap(KEY_F5)
	var saved:=Save.read_document(Save.slot_path(1));assert(saved.error.is_empty(),"real F5 defaults to slot1")
	var p: Array=saved.state.area_save.player.position;var at:=Vector3(p[0],p[1],p[2])
	await walk_a_bit();assert(scene.player.position.distance_to(at)>4,"real movement changes position")
	var prior:=scene.get_instance_id();await tap(KEY_F9);await reload_finished(prior)
	assert(scene.player.position.distance_to(at)<2,"real F9 restores the saved pose")
	await tap(KEY_TAB);assert(scene.interface_hud.cursor_active)
	await click_button(scene.interface_hud.buttons[0]);await ticks(2)
	await click_button(scene.interface_hud.save_button);await ticks(2)
	var panel: CanvasLayer=scene.interface_hud.slot_panel
	assert(is_instance_valid(panel) and panel.saving)
	await click_button(panel.rows.get_node("Slot_03"));assert(FileAccess.file_exists(Save.slot_path(3)))
	var bytes:=FileAccess.get_file_as_bytes(Save.slot_path(3))
	await click_button(panel.rows.get_node("Slot_03"));await ticks(2)
	assert(panel.confirmation.visible and FileAccess.get_file_as_bytes(Save.slot_path(3))==bytes,"one overwrite confirmation before writing")
	await click_button(panel.confirm_yes);await ticks(2)
	assert(not panel.confirmation.visible and FileAccess.get_file_as_bytes(Save.backup_path(3))==bytes)
	await tap(KEY_ESCAPE);await ticks(2)
	await click_button(scene.interface_hud.load_button);await ticks(2)
	panel=scene.interface_hud.slot_panel;assert(is_instance_valid(panel) and not panel.saving)
	await RenderingServer.frame_post_draw
	var folder: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-proof="):folder=arg.substr(13)
	root.get_texture().get_image().save_png(folder+"/slots.png")
	prior=scene.get_instance_id();await click_button(panel.rows.get_node("Slot_03"));await reload_finished(prior)
	assert(preload("res://scripts/lol2/game_session.gd").for_tree(self).last_slot==3)
	assert(scene.resets==0 and scene.starting_magic.health()>0)
	print("PASS real F5, movement, F9; Tab/portrait/Save/slot3; single overwrite confirmation; Load slot3; resets=0")
	quit()
