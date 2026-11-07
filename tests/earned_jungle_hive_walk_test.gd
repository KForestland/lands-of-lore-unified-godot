extends SceneTree
var broken_route := "--broken-sword" in OS.get_cmdline_user_args()
var spell_route := "--starting-spells" in OS.get_cmdline_user_args()
var input_save: String
var output_save: String
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> bool:
	if value: return true
	push_error(message)
	quit(1)
	return false
func run() -> void:
	input_save = "user://tests/act1_magic_museum_jungle.json" if spell_route else "user://tests/act1_earned_museum_jungle.json"
	output_save = "user://tests/act1_magic_hive_entry.json" if spell_route else "user://tests/act1_cave_hive_entry.json"
	if broken_route:
		input_save = "user://tests/act1_broken_museum_jungle.json"
		output_save = "user://tests/act1_broken_hive_entry.json"
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 32
	var proof = JSON.parse_string(FileAccess.get_file_as_string("res://docs/museum-broken-sword-earned-checks.json" if broken_route else "res://docs/museum-starting-spells-jungle-walk-checks.json" if spell_route else "res://docs/museum-earned-jungle-walk-checks.json"))
	if not check(FileAccess.get_sha256(input_save) == proof.output_sha256,"Earned Museum/Jungle save differs"): return
	var saved = preload("res://scripts/lol2/jungle_save.gd").read_save(input_save)
	if not check(saved.error.is_empty(),"Invalid earned Jungle save"): return
	set_meta("lol2_jungle_resume",saved.state)
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var route = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_jungle_hive_walk_route.json"))
	var forward := InputEventKey.new()
	forward.keycode = KEY_W
	forward.physical_keycode = KEY_W
	forward.pressed = true
	Input.parse_input_event(forward)
	var transitioned := false
	for index in route.points.size():
		if index % 20 == 0: print("Earned Jungle waypoint ",index," region ",route.regions[index])
		var target := Vector2(route.points[index][0],route.points[index][1])
		var reached := false
		for step in range(1800):
			await physics_frame
			if not is_instance_valid(scene) or current_scene != scene:
				transitioned = true
				break
			if scene.village_dialogue.active():
				for tick in range(12000):
					await physics_frame
					if not scene.village_dialogue.active(): break
				if not check(not scene.village_dialogue.active(),"Jungle conversation stalled"): return
			if Vector2(scene.player.position.x,scene.player.position.z).distance_to(target) < 3:
				reached = true
				break
			scene.player.look_at(Vector3(target.x,scene.player.position.y,target.y))
			scene.camera.rotation = Vector3.ZERO
			if not check(scene.resets == 0 and not scene.flying and scene.health > 0,"Earned Jungle route reset or died"): return
		if transitioned: break
		if not reached:
			for collision in range(scene.player.get_slide_collision_count()):
				var hit = scene.player.get_slide_collision(collision)
				print("Blocked contact=",hit.get_position()," normal=",hit.get_normal())
			check(false,"Earned Jungle route blocked at %s region%s target%s player%s" % [index,route.regions[index],target,scene.player.position])
			return
	forward = forward.duplicate()
	forward.pressed = false
	Input.parse_input_event(forward)
	for tick in range(180):
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/lol2/hive_review.tscn": break
	if not check(is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/lol2/hive_review.tscn","No actual Hive transition"): return
	var hive = current_scene
	for tick in range(90): await physics_frame
	if not check(hive.player.is_on_floor() and hive.resets == 0,"Earned Hive arrival not grounded"): return
	var carried: Dictionary = hive.area_handoff()
	if not check(carried.inventory.collected == saved.state.inventory.collected and carried.inventory.equipped_item == saved.state.inventory.equipped_item,"Earned inventory lost"): return
	if not check(carried.quests.shared_flag_38 == 0 and not carried.quests.hive_chasm.activated,"Rescue/chasm supplied before earning them"): return
	if not check(hive.quicksave(output_save).is_empty(),"Earned Hive save failed"): return
	if broken_route:
		if not check(carried.quests.museum_control181.owner_state == 1 and "museum:control181:Tho_Broken" in carried.inventory.collected,"Broken sword/history lost at Hive"): return
		var report = {"passed":true,"input_save":input_save,"input_sha256":FileAccess.get_sha256(input_save),"output_save":output_save,"output_sha256":FileAccess.get_sha256(output_save),"scope":"Earned Museum broken sword save, normal grounded Jungle walk and actual Hive transition. No position, inventory or quest injection; automated steering and accelerated clocks."}
		FileAccess.open("res://docs/broken-earned-jungle-hive-walk-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("PASS earned cave/Museum Jungle arrival→198-region human walk→actual Hive entry and grounded saved arrival, both earned weapons retained; no position, form, inventory or quest injection")
	hive.queue_free()
	await process_frame
	await process_frame
	quit()
