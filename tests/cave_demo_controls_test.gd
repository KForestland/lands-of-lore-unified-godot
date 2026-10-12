extends SceneTree
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> bool:
	if not ok:push_error(message);quit(1)
	return ok
func send(host,code: int) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.pressed=true
	host._unhandled_input(e)
func run() -> void:
	var cave=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave);current_scene=cave
	for i in range(600):
		await process_frame
		if cave.walkthrough_ready:break
	if not check(cave.walkthrough_ready and not cave.development_mode,"Demo profile failed to initialize"):return
	cave.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var position: Vector3=cave.player.global_position
	var checkpoint: int=cave.checkpoint
	var resets: int=cave.resets
	var props: bool=cave.props_root.visible
	var roof: bool=cave.roof.visible
	for code in [KEY_F,KEY_N,KEY_P,KEY_R,KEY_V,KEY_K,KEY_B,KEY_C,KEY_G,KEY_L,KEY_T]:send(cave,code)
	if not check(not cave.flying and cave.player.global_position==position and cave.checkpoint==checkpoint and cave.resets==resets and not is_instance_valid(cave.video_overlay) and cave.props_root.visible==props and cave.roof.visible==roof,"Demo admitted a diagnostic hotkey"):return
	send(cave,KEY_ESCAPE)
	if not check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Escape did not release mouse"):return
	var click:=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
	cave._unhandled_input(click)
	if not check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"Click did not resume mouse"):return
	send(cave,KEY_I);await process_frame
	if not check(is_instance_valid(cave.inventory),"Normal inventory key blocked"):return
	cave.inventory.queue_free();await process_frame
	paused=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	cave.roach.model.player_health=0
	send(cave,KEY_R)
	if not check(cave.roach.model.player_health>0 and cave.checkpoint==checkpoint,"Death recovery key blocked"):return
	for i in range(3):await process_frame
	if not check(not cave.flight_label.visible and "F fly" not in cave.hud.text and "V: video review" not in cave.hud.text and "F5 save" in cave.hud.text,"Demo HUD exposes diagnostics or loses save guidance"):return
	await RenderingServer.frame_post_draw
	cave.queue_free();await process_frame
	print("PASS cave demo controls: diagnostic keys blocked, inventory/Escape/capture preserved, death R works, HUD simplified; supplied fixture, not earned campaign")
	quit()
