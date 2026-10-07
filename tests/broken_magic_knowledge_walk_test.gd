extends "res://tests/weapon_shop_earned_walk_test.gd"
const Magic = preload("res://scripts/lol2/magic_shop_state.gd")
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
	var input_path := "user://tests/act1_broken_runes_monastery_return.json"
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/broken-hive-earned-rune-return-checks.json"))
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
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/magic_shop_walk.json"))
	if not await walk_shop(routes.to_shop,"MAGIC"): return
	for tick in range(9000):
		await process_frame
		if not Magic.active(scene.magic_shop.state()): break
	if Magic.active(scene.magic_shop.state()) or not scene.magic_shop.offer_item("museum:control181:Tho_Broken"):
		fail("Original Rashar introduction or earned broken sword offer failed")
		return
	for tick in range(6000):
		await process_frame
		if not Magic.active(scene.magic_shop.state()): break
	if Magic.active(scene.magic_shop.state()) or scene.quest_state.monastery.globals.get("GV_KNOWLEDGE_OF_POWER_ORB",0) != 1:
		fail("Broken sword did not earn orb knowledge")
		return
	scene.magic_shop.leave_room()
	for tick in range(6000):
		await process_frame
		if not scene.magic_shop.active(): break
	if scene.magic_shop.active():
		fail("Rashar exit did not finish")
		return
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
	var output_path := "user://tests/act1_broken_orb_monastery.json"
	if not scene.quicksave(output_path).is_empty():
		fail("Shop knowledge output could not save")
		return
	var report := {"passed":true,"input_path":input_path,"input_sha256":FileAccess.get_sha256(input_path),"input_proof":"docs/broken-hive-earned-rune-return-checks.json","output_path":output_path,"output_sha256":FileAccess.get_sha256(output_path),"inventory":original,"scope":"Cave-derived earned rune-return checkpoint; continuous source-portal walk from monastery to MAGIC, original Rashar introduction, earned broken sword offer and power-orb knowledge, return walk, original garden/cellar conversations and Julian empty-hand response. No position/form/quest injection after load. Movement/curse ticks manually driven, time/audio4x. Shop item and other content acceptance remain separate."}
	FileAccess.open("res://docs/broken-magic-knowledge-walk-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: earned cave-derived Rashar broken sword orb knowledge and return to Julian without quest injection")
	quit()
