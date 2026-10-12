extends "res://tests/museum_exhibit_route_test.gd"
## Resume an earned cave save; use normal movement and original scene transitions.
var broken_route := "--broken-sword" in OS.get_cmdline_user_args()
var spell_route := "--starting-spells" in OS.get_cmdline_user_args()
var input_save: String
var output_save: String
var earned_routes: Dictionary
func check(value: bool, message: String) -> bool:
	if value: return true
	push_error(message)
	quit(1)
	return false
func run():
	input_save = "user://tests/act1_magic_museum_arrival.json" if spell_route else "user://tests/act1_earned_museum_arrival.json"
	output_save = "user://tests/act1_magic_museum_jungle.json" if spell_route else "user://tests/act1_earned_museum_jungle.json"
	if broken_route:
		input_save = "user://tests/act1_magic_museum_arrival.json"
		output_save = "user://tests/act1_broken_museum_jungle.json"
		spell_route = true
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 32
	var proof = JSON.parse_string(FileAccess.get_file_as_string("res://docs/cave-starting-spells-walk-checks.json" if spell_route else "res://docs/cave-earned-museum-walk-checks.json"))
	if not check(FileAccess.get_sha256(input_save) == proof.output_sha256,"Earned cave save hash differs"): return
	var loaded = preload("res://scripts/lol2/museum_save.gd").read_save(input_save)
	if not check(loaded.error.is_empty(),"Earned cave save is invalid"): return
	set_meta("lol2_museum_resume",loaded.state)
	var scene = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The saved cave curse expires normally before the human-sized museum route.
	for frame in range(6000):
		await physics_frame
		if scene.player_form == 0 and scene.player.is_on_floor(): break
	print("Saved curse after wait: ",scene.curse.snapshot()," form=",scene.player_form," active=",scene.curse.active()," position=",scene.player.position)
	if not check(scene.player_form == 0 and scene.curse.state.phase == 0,"Earned form did not expire normally"): return
	earned_routes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/museum_earned_walk_routes.json"))
	if not await walk_points(scene,earned_routes.arrival_to_sword_trigger.points,"arrival_to_sword_trigger"): return
	# Wait clear of the swinging gate while the skeleton places the gift.
	for frame in range(1200):
		await physics_frame
		if scene.sword_transfer.phase == "complete" and scene.museum_gate.progress == 1: break
	if not check(scene.sword_transfer.phase == "complete" and scene.museum_gate.progress == 1,"Walked source trigger did not finish sword/gate sequence"): return
	if not await walk_points(scene,earned_routes.trigger_to_sword.points,"trigger_to_sword"): return
	for frame in range(900):
		await physics_frame
		if scene.sword_transfer.available: break
	scene.camera.look_at(scene.sword_transfer.TABLE_SWORD)
	if not scene.can_take_sword():
		var ray := PhysicsRayQueryParameters3D.create(scene.camera.global_position,scene.sword_transfer.TABLE_SWORD,1,[scene.player.get_rid()])
		print("Sword ray ",scene.get_world_3d().direct_space_state.intersect_ray(ray)," camera=",scene.camera.global_position," player=",scene.player.position)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tmp/museum_earned_sword_block.png")
	if not check(scene.take_sword(),"Walked sword pickup failed"): return
	if not check(scene.set_equipped_item(scene.SWORD_ITEM_ID),"Earned sword equip failed"): return
	if broken_route:
		var detour = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/museum_broken_sword_walk_routes.json"))
		if not await walk_points(scene,detour.sword_to_case.points,"sword_to_case"): return
		scene.camera.look_at(scene.broken_thohan.aim_point())
		if not check(scene.broken_thohan.use(),"Walked Broken Thohan pickup failed"): return
		if not check(scene.hold_for_exhibit(scene.broken_thohan.ITEM),"Could not stow earned Broken Thohan"): return
		if not await walk_points(scene,detour.case_to_gallery.points,"case_to_gallery"): return
	else:
		if not await walk_points(scene,earned_routes.sword_to_gallery.points,"sword_to_gallery"): return
	scene.camera.look_at(scene.gallery.painting.global_position)
	if not check(scene.use_gallery(),"Walked painting interaction failed"): return
	scene.camera.look_at(scene.gallery.lever.global_position)
	if not check(scene.use_gallery(),"Walked lever interaction failed"): return
	if not await walk_route(scene,"gallery_hourglass"): return
	scene.camera.look_at(scene.hourglass.global_position+Vector3(0,31,0))
	if not check(scene.strike_hourglass(),"Earned sword did not strike hourglass"): return
	if not await walk_route(scene,"hourglass_wall"): return
	scene.camera.look_at(scene.escape_wall.global_position)
	for frame in range(660):
		await physics_frame
		if scene.escape_wall.stage > 0: break
	for strike in range(3):
		if not check(scene.strike_escape_wall(),"Earned escape-wall strike failed"): return
	if not await walk_points(scene,[[1460,-492]],"wall crossing"): return
	if not await walk_route(scene,"escape_dragon"): return
	scene.player.rotation = Vector3.ZERO
	scene.camera.rotation = Vector3.ZERO
	if not check(scene.hourglass.escaped and scene.enter_dragon(),"Earned dragon departure failed"): return
	for frame in range(18000):
		await process_frame
		if not is_instance_valid(scene): break
	if not check(not is_instance_valid(scene),"Natural dragon movie did not transition"): return
	var jungle = current_scene
	if not check(jungle.scene_file_path == "res://scenes/lol2/jungle_walkthrough.tscn","Wrong dragon destination"): return
	for frame in range(90): await physics_frame
	if not check(jungle.player.is_on_floor() and jungle.resets == 0,"Earned Jungle arrival not grounded"): return
	if not check(jungle.equipped_item == jungle.SWORD_ITEM_ID and "cave:prop641:harvest1:Stalagmite" in jungle.carried_collected,"Earned equipment lost in Jungle"): return
	if not check(jungle.quicksave(output_save).is_empty(),"Earned Jungle save failed"): return
	if broken_route:
		if not check("museum:control181:Tho_Broken" in jungle.carried_collected and jungle.quest_state.museum_control181.owner_state == 1,"Earned broken sword or exhibit history lost"): return
	if spell_route:
		var magic: Dictionary = jungle.quest_state.player_magic_reward_state
		if not check(magic.spell == loaded.state.checkpoint.magic.spell and magic.player.level == loaded.state.checkpoint.magic.player.level, "Starting spell selection/level lost in Jungle"): return
		var evidence := {"passed":true,"input_save":input_save,"input_sha256":FileAccess.get_sha256(input_save),"output_save":output_save,"output_sha256":FileAccess.get_sha256(output_save),"magic":magic,"scope":"Earned spell-using cave save through natural curse expiry, Museum puzzles and original dragon movie to grounded Jungle. Automated walking/4x clock, no injected position, inventory, quest or magic state."}
		if broken_route:
			evidence["broken_sword"] = {"owned": "museum:control181:Tho_Broken" in jungle.carried_collected, "control": jungle.quest_state.museum_control181}
			evidence["scope"] += " Includes walked sword-to-case-to-gallery detour and earned Broken Thohan pickup; no orb or repair is claimed."
		var file := FileAccess.open("res://docs/museum-broken-sword-earned-checks.json" if broken_route else "res://docs/museum-starting-spells-jungle-walk-checks.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(evidence,"  ")+"\n")
		file.close()
	print("PASS earned cave save→natural form expiry→sword sequence/pickup→gallery/hourglass/wall/dragon→natural movie→grounded Jungle save; no position, inventory or quest injection")
	jungle.queue_free()
	await process_frame
	quit()
## Source Museum skeletons/Rat now wake and fight. Engage any that are active or
## adjacent through the production mouse strike; no damage/health/position injection.
var creature_kills: Array = []
func fight_creatures(scene) -> void:
	var pop = scene.get("skeleton_population")
	if pop == null: return
	const Live = preload("res://scripts/lol2/creature_live_rules.gd")
	for round in range(3600):
		var target := ""
		var closest := 110.0
		for id in pop.bodies:
			if pop.state.actors[id].health <= 0: continue
			var d: float = pop.bodies[id].global_position.distance_to(scene.player.global_position)
			var active: bool = pop.state.live[id].mode != Live.IDLE or (pop.state.actors[id].woken and d < 70)
			if (active or d < 45) and d < closest: closest = d;target = id
		if target.is_empty() or scene.health <= 0: return
		# Heal through the production spell keys when low, as a player would.
		if scene.health <= 12 and scene.player_magic_checkpoint.player.mana >= 2 and is_instance_valid(scene.starting_magic) and not scene.starting_magic.protected():
			# Select Healing, cast, then re-select the previous spell (a player switches back to Spark after healing).
			var back := KEY_1 if str(scene.player_magic_checkpoint.get("spell","spark")) == "spark" else KEY_2
			for code in [KEY_2, KEY_Q, back]:
				var key := InputEventKey.new();key.keycode = code;key.pressed = true
				Input.parse_input_event(key);Input.flush_buffered_events()
		var held := InputEventKey.new();held.keycode = KEY_W;held.physical_keycode = KEY_W;held.pressed = false
		Input.parse_input_event(held)
		var point: Vector3 = pop.bodies[target].global_position+Vector3(0,24,0)
		scene.player.look_at(Vector3(point.x,scene.player.position.y,point.z))
		scene.camera.look_at(point)
		if pop.strike_remaining <= 0 and pop.aimed() == target:
			var strike := InputEventMouseButton.new();strike.button_index = MOUSE_BUTTON_LEFT;strike.pressed = true
			pop._unhandled_input(strike)
		elif closest > 60:
			var press := InputEventKey.new();press.keycode = KEY_W;press.physical_keycode = KEY_W;press.pressed = true
			Input.parse_input_event(press)
		await physics_frame
		if pop.state.actors[target].health <= 0:
			creature_kills.append({"actor":int(target),"health":scene.health})
			print("Museum creature",target," defeated; player health=",scene.health)

func walk_points(scene, points: Array, label: String) -> bool:
	var forward := InputEventKey.new()
	forward.keycode = KEY_W
	forward.physical_keycode = KEY_W
	forward.pressed = true
	Input.parse_input_event(forward)
	for i in range(points.size()):
		if i % 20 == 0: print(label," ",i,"/",points.size())
		var target := Vector2(points[i][0],points[i][1])
		var reached := false
		for step in range(1800):
			await fight_creatures(scene)
			if not Input.is_physical_key_pressed(KEY_W): Input.parse_input_event(forward)
			var offset := target-Vector2(scene.player.position.x,scene.player.position.z)
			if offset.length() < 3:
				reached = true
				break
			scene.player.look_at(Vector3(target.x,scene.player.position.y,target.y))
			scene.camera.rotation = Vector3.ZERO
			if not scene.dragon_door.opened and scene.camera.global_position.distance_to(scene.dragon_door.global_position+Vector3(0,35,0)) < 90:
				scene.camera.look_at(scene.dragon_door.global_position+Vector3(0,35,0))
				scene.open_dragon_door()
			await physics_frame
			if not check(scene.resets == 0 and not scene.flying and scene.health > 0,"Earned museum walk reset or died"): return false
		if not reached:
			for collision in range(scene.player.get_slide_collision_count()):
				var hit = scene.player.get_slide_collision(collision)
				print("Blocked contact=",hit.get_position()," normal=",hit.get_normal()," collider=",hit.get_collider().get_path())
			return check(false,"%s blocked at %d target %s player %s" % [label,i,target,scene.player.position])
	forward = forward.duplicate()
	forward.pressed = false
	Input.parse_input_event(forward)
	return true

func walk_route(scene, name: String) -> bool:
	if earned_routes.has(name): return await walk_points(scene,earned_routes[name].points,name)
	return await super.walk_route(scene,name)
