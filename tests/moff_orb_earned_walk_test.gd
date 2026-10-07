extends "res://tests/weapon_shop_earned_walk_test.gd"
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
	var input_path = "user://tests/act1_shop_runes_translated.json"
	var proof = JSON.parse_string(FileAccess.get_file_as_string("res://docs/shop-monastery-rune-offer-live-checks.json"))
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
	var routes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/weapon_shop_walk.json"))
	if not await walk_shop(routes.to_shop,"WPNEXT"): return
	if not scene.weapon_shop.interact("enter") or not scene.weapon_shop.offer_item(Speech.ORB):
		fail("Earned orb trade rejected")
		return
	for tick in range(6000):
		await process_frame
		if not Wpn.active(scene.weapon_shop.state()): break
	if Speech.ORB in scene.carried_collected or Wpn.ITEMS["9-Firestorm"] not in scene.carried_collected:
		fail("Earned orb exchange failed")
		return
	scene.weapon_shop.leave_room()
	scene.weapon_shop.leave_room()
	scene.set_physics_process(false)
	if not await walk_shop(routes.to_monastery,"MENT"): return
	var output_path = "user://tests/act1_earned_firestorm_monastery.json"
	if not scene.quicksave(output_path).is_empty():
		fail("Earned Firestorm checkpoint invalid")
		return
	var report = {"passed":true,"input_sha256":FileAccess.get_sha256(input_path),"output_sha256":FileAccess.get_sha256(output_path),"scope":"Earlier earned translation checkpoint, original translation-visit exit, translated revisit, delayed orb grant, original Morgan blessing/returned orb, normal grounded shop walk and orb-for-Firestorm exchange, walk back to monastery. No position/form/quest injection. Modern movement/curse ticks manually driven and time/audio4x. Earlier legs reused; not full Act One acceptance."}
	FileAccess.open("res://docs/moff-orb-earned-walk-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("PASS: earned Julian orb, normal WPN walk, Firestorm exchange and monastery return")
	scene.queue_free()
	await process_frame
	await process_frame
	quit()
