extends "res://tests/weapon_shop_earned_walk_test.gd"
const Magic = preload("res://scripts/lol2/magic_shop_state.gd")
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
func wait_speech() -> bool:
	for tick in range(6000):
		await process_frame
		if not Speech.active(scene.monastery.state().conversation): return true
	return fail("Julian dialogue did not finish")
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
	var input_path = "user://tests/act1_broken_runes_translated.json"
	var proof = JSON.parse_string(FileAccess.get_file_as_string("res://docs/broken-monastery-rune-offer-live-checks.json"))
	if FileAccess.get_sha256(input_path) != proof.output_sha256 or not scene.quickload(input_path).is_empty():
		fail("Earned translation input mismatch")
		return
	if Speech.ORB in scene.carried_collected:
		fail("Input already contains orb")
		return
	scene.monastery.leave_room()
	if not await wait_speech(): return
	if scene.monastery.state().room != "MENT" or Speech.ORB in scene.carried_collected:
		fail("Translation visit prematurely granted orb")
		return
	if not scene.monastery.enter_room("MOFF"):
		fail("Earned translated revisit rejected")
		return
	if not await wait_speech(): return
	scene.monastery.leave_room()
	if not await wait_speech(): return
	if scene.carried_collected.count(Speech.ORB) != 1 or scene.monastery.state().room != "MENT":
		fail("Revisit did not grant one orb")
		return
	if not scene.monastery.enter_room("MGAR"):
		fail("Earned orb did not permit garden visit")
		return
	if not await wait_speech(): return
	if not scene.monastery.offer_item(Speech.ORB):
		fail("Morgan rejected earned orb")
		return
	if not await wait_speech(): return
	if scene.monastery.state().flags.get("259",0) != 1 or scene.carried_collected.count(Speech.ORB) != 1:
		fail("Morgan did not return earned orb")
		return
	scene.monastery.leave_room()
	scene.monastery.leave_room()
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var routes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/magic_shop_walk.json"))
	if not await walk_shop(routes.to_shop,"MAGIC"): return
	for tick in range(6000):
		await process_frame
		if not Magic.active(scene.magic_shop.state()): break
	if Magic.active(scene.magic_shop.state()) or not scene.magic_shop.offer_item(Speech.ORB):
		fail("Rashar rejected earned orb")
		return
	for tick in range(6000):
		await process_frame
		if not Magic.active(scene.magic_shop.state()): break
	if Magic.active(scene.magic_shop.state()) or not scene.magic_shop.offer_item("museum:control181:Tho_Broken"):
		fail("Rashar rejected earned broken sword repair")
		return
	for tick in range(6000):
		await process_frame
		if not Magic.active(scene.magic_shop.state()): break
	if Magic.active(scene.magic_shop.state()) or Speech.ORB in scene.carried_collected or "museum:control181:Tho_Broken" in scene.carried_collected or scene.carried_collected.count("jungle:magic_shop:Tho_fixed") != 1:
		fail("Earned Thohan repair did not consume orb/broken sword and grant one repaired sword")
		return
	scene.magic_shop.leave_room()
	for tick in range(6000):
		await process_frame
		if not scene.magic_shop.active(): break
	if scene.magic_shop.active():
		fail("Repaired sword shop exit stalled")
		return
	scene.set_physics_process(false)
	if not await walk_shop(routes.to_monastery,"MENT"): return
	var output_path = "user://tests/act1_broken_repaired_monastery.json"
	if not scene.quicksave(output_path).is_empty():
		fail("Earned Thohan repair checkpoint invalid")
		return
	var report = {"passed":true,"input_sha256":FileAccess.get_sha256(input_path),"output_sha256":FileAccess.get_sha256(output_path),"scope":"Earlier earned translation checkpoint, original translation-visit exit, translated revisit, delayed orb grant, original Morgan blessing/returned orb, normal grounded shop walk and orb and broken sword repair exchange, walk back to monastery. No position/form/quest injection. Modern movement/curse ticks manually driven and time/audio4x. Earlier legs reused; not full Act One acceptance."}
	FileAccess.open("res://docs/broken-repair-earned-walk-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("PASS: earned Julian orb, normal MAGIC walk, Thohan repair exchange and monastery return")
	scene.queue_free()
	await process_frame
	await process_frame
	quit()
