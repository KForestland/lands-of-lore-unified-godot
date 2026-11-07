extends SceneTree
func _initialize(): run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run():
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	root.grab_focus()
	for frame in range(3): await process_frame
	var input_path := "user://tests/act1_departure_ready.json"
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/act-one-departure-walk-checks.json"))
	if not check(FileAccess.get_sha256(input_path)==proof.output_sha256,"Earned departure save differs from proof"): return
	scene.departure.set_process(false)
	if not check(scene.quickload(input_path).is_empty(),"Earned departure save rejected"): return
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for tick in range(10):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	var inventory: Dictionary = scene.inventory_state()
	if not check(scene.departure.begin() and scene.departure.state().phase=="movie","Grounded source exit did not start first movie"): return
	if not check(not scene.open_inventory() and not scene.is_physics_processing(),"Departure failed to lock world input"): return
	for code in [KEY_TAB,KEY_M,KEY_I,KEY_SPACE]: key(code)
	if not check(not scene.interface_hud.cursor_active and not scene.jump_requested and not scene.is_physics_processing(),"Movie allowed interface/movement input"): return
	scene.departure.advance(3.25)
	var partial := "user://tests/act1_departure_partial.json"
	scene.area_save_path = partial
	scene.interface_hud.save_path = partial
	key(KEY_F5)
	if not check(FileAccess.file_exists(partial),"Movie F5 save failed"): return
	scene.departure.advance(2)
	key(KEY_F9)
	if not check(is_equal_approx(scene.departure.state().elapsed,3.25),"Movie F9 clock rollback failed"): return
	if not check(scene.departure.atlas.region==Rect2(0,0,640,400) and scene.departure.page==3,"Movie frame did not resume at48"): return
	await process_frame
	await process_frame
	var invalid: Dictionary = scene.area_handoff()
	invalid.quests.act_one_departure.local55 = 0
	if not check(not scene.apply_area_handoff(invalid).is_empty() and scene.departure.state().phase=="movie","Malformed pending movie was accepted"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/act1_departure_movie.png")
	# Let production playback finish at its normal rate, including final audio.
	scene.departure.set_process(true)
	for frame in range(2400):
		await process_frame
		if current_scene != scene and is_instance_valid(current_scene): break
	if not check(is_instance_valid(current_scene) and current_scene.scene_file_path=="res://scenes/lol2/darker_jungle.tscn","Original movie did not transition to darker jungle"): return
	scene = current_scene
	scene.set_physics_process(false)
	for tick in range(30):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	if not check(scene.player.is_on_floor() and scene.resets==0 and absf(scene.player.position.y-32)<.2,"Darker jungle source arrival did not ground"): return
	if not check(Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(-4577,1168))<.1 and is_equal_approx(scene.player.rotation.y,-PI/2),"Darker jungle arrival position/bearing differs"): return
	if not check(scene.inventory_state()==inventory and scene.quest_state.monastery.globals.GV_RUNES_TRANSLATED==1 and scene.quest_state.act_one_departure.phase=="arrived","Transition lost earned inventory/quest/form state"): return
	var output_path := "user://tests/act1_darker_jungle_arrival.json"
	if not check(scene.quicksave(output_path).is_empty(),"Darker jungle save failed"): return
	var position: Vector3 = scene.player.position
	if not check(not scene.quickload(partial).is_empty() and scene.player.position==position,"Darker jungle accepted a Huline scene save"): return
	if not check(scene.quickload(output_path).is_empty(),"Darker jungle save resume failed"): return
	scene.set_physics_process(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/act1_darker_jungle_arrival.png")
	var arrival_position: Vector3 = scene.player.position
	for tick in range(60):
		await physics_frame
		scene.move_grounded(Vector3.RIGHT,scene.player.get_physics_process_delta_time())
	if not check(scene.player.is_on_floor() and scene.resets==0 and scene.player.position.x-arrival_position.x>20,"Destination arrival could not be walked onward"): return
	var report := {"passed":true,"input_sha256":FileAccess.get_sha256(input_path),"output_sha256":FileAccess.get_sha256(output_path),"position":[arrival_position.x,arrival_position.y,arrival_position.z],"walked_position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"scope":"Earned departure-ready save, original polygon admission, first-use source movie/PCM audio, input lock, partial frame/clock disk rollback, malformed rollback, natural finish, real scene transition, original L8_SJ entry1 grounding/bearing, inventory/quests/forms carry and destination-specific saves. Original start-to-finish Act1 and full Act2 content not established."}
	var file := FileAccess.open("res://docs/act-one-departure-live-checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: original departure movie, partial save, real darker jungle arrival and destination persistence")
	quit()
