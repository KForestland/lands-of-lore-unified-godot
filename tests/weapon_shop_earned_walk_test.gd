extends "res://tests/hive_earned_rune_return_test.gd"
const Wpn = preload("res://scripts/lol2/weapon_shop_state.gd")
func walk_shop(route: Dictionary, target_room: String) -> bool:
	for index in range(route.points.size()):
		var target := Vector2(route.points[index][0],route.points[index][1])
		var reached := false
		for step in range(1200):
			await physics_frame
			if target_room == "MAGIC" and scene.magic_shop.active(): return true
			if target_room == "WPNEXT" and scene.weapon_shop.active(): return true
			if target_room == "MENT" and scene.monastery.active(): return scene.monastery.state().room == "MENT"
			if scene.magic_shop.active(): return fail("Shop walk entered unexpected MAGIC room")
			# Let production conversation holds finish before issuing another movement
			# request. The owner advances its own clock and releases the player.
			if scene.actor_input_locked():
				for wait_tick in range(6000):
					await process_frame
					if not scene.actor_input_locked(): break
				if scene.actor_input_locked(): return fail("Shop walk story hold did not finish")
			var offset := target-Vector2(scene.player.position.x,scene.player.position.z)
			if offset.length()<2 and scene.player.is_on_floor():
				reached = true
				break
			var delta: float = scene.player.get_physics_process_delta_time()
			var direction := offset.normalized()*minf(1,offset.length()/(80*delta))
			scene.move_grounded(Vector3(direction.x,0,direction.y),delta)
			scene.curse.advance(delta)
			if scene.resets != 0 or scene.flying: return fail("Shop walk reset or entered flight")
		if not reached:
			for collision in range(scene.player.get_slide_collision_count()):
				var hit = scene.player.get_slide_collision(collision)
				print("Shop blocked contact: ",hit.get_position()," normal=",hit.get_normal()," collider=",hit.get_collider().get_path())
			print("Shop gate poses: ",scene.village_gate.pose," / ",scene.followup_gate.pose," target=",target)
			return fail("Shop walk blocked at %s region%s position%s" % [index,route.regions[index],scene.player.position])
		if index%20==0: print("Shop waypoint ",index," region ",route.regions[index])
	return true
func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	AudioServer.playback_speed_scale = 4
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	root.grab_focus()
	var input_path := "user://tests/act1_magic_speech_runes_monastery_return.json"
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/magic-speech-hive-earned-rune-return-checks.json"))
	if FileAccess.get_sha256(input_path) != proof.output_sha256 or not scene.quickload(input_path).is_empty():
		fail("Earned shop input checkpoint/proof mismatch")
		return
	var original: Array = scene.carried_collected.duplicate()
	if scene.quest_state.monastery.globals.get("GV_KNOWLEDGE_OF_POWER_ORB",0) != 0:
		fail("Shop input already has orb knowledge")
		return
	scene.monastery.leave_room()
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/weapon_shop_walk.json"))
	if not await walk_shop(routes.to_shop,"WPNEXT"): return
	if not scene.weapon_shop.interact("enter"):
		fail("Earned shop route could not enter WPN")
		return
	for tick in range(6000):
		await process_frame
		if not Wpn.active(scene.weapon_shop.state()): break
	if Wpn.active(scene.weapon_shop.state()):
		fail("Original shop introduction did not finish")
		return
	scene.weapon_shop.interact("orb")
	for tick in range(3000):
		await process_frame
		if not Wpn.active(scene.weapon_shop.state()): break
	if scene.quest_state.monastery.globals.get("GV_KNOWLEDGE_OF_POWER_ORB",0) != 1:
		fail("Shop conversation did not earn knowledge")
		return
	scene.weapon_shop.leave_room()
	scene.weapon_shop.leave_room()
	scene.set_physics_process(false)
	if not await walk_shop(routes.to_monastery,"MENT"): return
	# Visit the original garden and cellar using prerequisites earned by the earlier flute route.
	for room in ["MGAR","MCEL"]:
		if not scene.monastery.enter_room(room):
			fail("Earned side-room admission failed: "+room)
			return
		for tick in range(3000):
			await process_frame
			if not preload("res://scripts/lol2/monastery_conversation.gd").active(scene.monastery.state().conversation): break
		if preload("res://scripts/lol2/monastery_conversation.gd").active(scene.monastery.state().conversation):
			fail("Side-room conversation did not finish")
			return
		scene.monastery.leave_room()
	if scene.quest_state.monastery.flags.get("170",0) != 1 or scene.quest_state.monastery.flags.get("258",0) != 1:
		fail("Earned side-room visit did not retain original flags")
		return
	if not scene.monastery.enter_room("MOFF"):
		fail("Earned office revisit rejected")
		return
	for tick in range(3000):
		await process_frame
		if not preload("res://scripts/lol2/monastery_conversation.gd").active(scene.monastery.state().conversation): break
	if not scene.monastery.offer_item(""):
		fail("Earned knowledge did not admit Julian discussion")
		return
	if scene.monastery.state().conversation.sequence != "MOFF_ORB":
		fail("Julian chose wrong earned knowledge response")
		return
	for tick in range(3000):
		await process_frame
		if not preload("res://scripts/lol2/monastery_conversation.gd").active(scene.monastery.state().conversation): break
	if scene.carried_collected != original:
		fail("Shop knowledge route lost earned inventory")
		return
	var output_path := "user://tests/act1_shop_orb_monastery.json"
	if not scene.quicksave(output_path).is_empty():
		fail("Shop knowledge output could not save")
		return
	var report := {"passed":true,"input_path":input_path,"input_sha256":FileAccess.get_sha256(input_path),"input_proof":"docs/magic-speech-hive-earned-rune-return-checks.json","output_path":output_path,"output_sha256":FileAccess.get_sha256(output_path),"inventory":original,"scope":"Cave-derived earned rune-return checkpoint; continuous source-portal walk from monastery to WPNEXT, first WPN conversation, object2 power-orb knowledge, return walk, original garden/cellar conversations and Julian empty-hand response. No position/form/quest injection after load. Movement/curse ticks manually driven, time/audio4x. Shop item and other content acceptance remain separate."}
	FileAccess.open("res://docs/weapon-shop-earned-walk-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: earned cave-derived WPN orb knowledge and return to Julian without quest injection")
	quit()
