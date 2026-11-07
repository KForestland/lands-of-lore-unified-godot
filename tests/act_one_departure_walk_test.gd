extends "res://tests/hive_earned_rune_return_test.gd"
class InputTrace extends Node:
	var previous_mode := -1
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			print("Departure input key: ",event.keycode)
	func _process(_delta: float) -> void:
		if previous_mode != Input.mouse_mode:
			print("Departure mouse mode: ",previous_mode," -> ",Input.mouse_mode," focused=",get_window().has_focus())
			previous_mode = Input.mouse_mode
func run() -> void:
	root.add_child(InputTrace.new())
	root.focus_exited.connect(func(): print("Departure window focus exited"))
	root.focus_entered.connect(func(): print("Departure window focus entered"))
	var full_exit := "--continue-departure" in OS.get_cmdline_user_args()
	Engine.time_scale = 4
	if full_exit: AudioServer.playback_speed_scale = 4
	Engine.physics_ticks_per_second = 240
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	root.grab_focus()
	for frame in range(3): await process_frame
	var firestorm := "--earned-firestorm" in OS.get_cmdline_user_args()
	var input_path := "user://tests/act1_broken_repaired_monastery.json" if broken_route else "user://tests/act1_earned_firestorm_monastery.json" if firestorm else chain_save("user://tests/act1_runes_translated.json")
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/broken-repair-earned-walk-checks.json" if broken_route else "res://docs/moff-orb-earned-walk-checks.json" if firestorm else chain_proof("res://docs/monastery-rune-offer-live-checks.json")))
	if FileAccess.get_sha256(input_path) != proof.output_sha256 or not scene.quickload(input_path).is_empty():
		fail("Earned translation checkpoint/proof mismatch")
		return
	var inventory: Array = scene.carried_collected.duplicate()
	if scene.monastery.state().room == "MOFF":
		scene.monastery.leave_room()
		for tick in range(3000):
			await process_frame
			if not preload("res://scripts/lol2/monastery_conversation.gd").active(scene.monastery.state().conversation): break
	if scene.monastery.state().room != "MENT":
		fail("Original office exit did not finish in monastery hall")
		return
	scene.monastery.leave_room()
	if not full_exit: scene.departure.set_process(false) # Retain the separately reproducible approach proof.
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/act_one_departure_route.json"))
	if not await walk_return(route,full_exit): return
	if full_exit:
		# X11 may release capture during automated room/quickload transitions.
		# Resume via the normal world click handler, as the wax-route driver does.
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not scene.departure.active():
			assert(not paused and not scene.monastery.active() and not scene.interface_hud.cursor_active)
			root.grab_focus()
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = Vector2(640,360)
			scene._unhandled_input(click)
			assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
		# Wait on presentation frames: 1800 physics ticks at 240 Hz cover only
		# 7.5 simulated seconds, shorter than the original 21.7-second movie.
		for tick in range(900):
			await process_frame
			if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/lol2/darker_jungle.tscn": break
		if not is_instance_valid(current_scene) or current_scene.scene_file_path != "res://scenes/lol2/darker_jungle.tscn":
			fail("Full earned departure did not reach darker jungle: " + str([scene.quest_state.act_one_departure, scene.departure.inside(), scene.ready_for_review, paused, scene.flying, scene.player.is_on_floor(), Input.mouse_mode, scene.interface_hud.cursor_active, scene.health, scene.monastery.active(), scene.village_dialogue.active(), scene.followup_dialogue.active(), scene.player.position]))
			return
		scene = current_scene
		scene.set_physics_process(false)
		for tick in range(30):
			await physics_frame
			scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	if scene.resets != 0 or not scene.player.is_on_floor() or scene.carried_collected != inventory or scene.quest_state.monastery.globals.GV_RUNES_TRANSLATED != 1:
		fail("Earned departure approach lost ground or quest state")
		return
	var output_path := chain_save("user://tests/act1_earned_darker_arrival.json") if full_exit else chain_save("user://tests/act1_departure_ready.json")
	if firestorm: output_path = "user://tests/act1_firestorm_darker_arrival.json"
	if broken_route and (scene.carried_collected.count("jungle:magic_shop:Tho_fixed") != 1 or scene.quest_state.museum_control181.owner_state != 1):
		fail("Repaired Thohan or exhibit history lost at departure")
		return
	var save_error: String = scene.quicksave(output_path)
	if not save_error.is_empty():
		fail("Departure approach save failed: "+save_error)
		return
	var report := {"passed":true,"input_sha256":FileAccess.get_sha256(input_path),"output_sha256":FileAccess.get_sha256(output_path),"position":[scene.player.position.x,scene.player.position.y,scene.player.position.z],"regions":route.regions.size(),"scope":"Earned translated-runes office checkpoint, actual office/hall exits,174-region grounded walk to source outbound region3188, inventory/translated state preserved. No test reposition/form/quest injection. Movement/curse ticks driven manually. Exit movie/transition/arrival not yet implemented; this verifies approach only."}
	if full_exit:
		report.scope = "Earned translated-runes office checkpoint through normal room exits, source174-region route, first-use exit movie, actual darker-jungle transition and grounded arrival with earned inventory/global retained. No test position/form/quest injection. Movement/curse ticks driven manually; time and audio accelerated4x for this route check. Full earlier cave/Museum continuity and remaining Act1 content not proved."
		report.departure = scene.quest_state.act_one_departure
	if cave_chain:
		report.cave_derived = true
		report.inventory = scene.carried_collected.duplicate()
		report.scope = report.scope.replace("Full earlier cave/Museum continuity and remaining Act1 content not proved.","Input chain is linked to original cave entry through Museum and Hive quests; full required-content and owner acceptance remain open.")
	if firestorm:
		report.inventory = scene.carried_collected.duplicate()
		report.scope = "Earned Julian orb/Firestorm monastery return through normal hall exit, grounded174-region departure walk, original movie and darker-jungle arrival. No position/form/quest injection. Prior cave-derived legs reused; modern movement/curse ticks manually driven and time/audio4x. Full Act One acceptance remains open."
	var file := FileAccess.open("res://docs/firestorm-act-one-departure-checks.json" if firestorm else chain_proof("res://docs/act-one-departure-full-walk-checks.json" if full_exit else "res://docs/act-one-departure-walk-checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: earned translated runes through actual exit movie and darker jungle arrival" if full_exit else "PASS: earned translated runes to original departure region without repositioning")
	quit()
