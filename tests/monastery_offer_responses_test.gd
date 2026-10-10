extends SceneTree
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
const State = preload("res://scripts/lol2/monastery_quest_state.gd")
func _initialize(): run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func same_speech(a: Dictionary, b: Dictionary) -> bool:
	return a.sequence == b.sequence and a.cursor == b.cursor and is_equal_approx(a.elapsed,b.elapsed)
func finish(rooms) -> bool:
	for frame in range(3000):
		if not Speech.active(rooms.state().conversation): return true
		await process_frame
	return check(false,"Julian response did not finish naturally")
func run():
	Engine.time_scale = 4
	var legacy := State.initial()
	legacy.flags.erase("143")
	legacy.globals.erase("GV_KNOWLEDGE_OF_POWER_ORB")
	if not check(State.validate(legacy).is_empty(),"Legacy monastery state rejected"): return
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	var data: Dictionary = scene.area_handoff()
	data.inventory.collected.append(Speech.FLUTE)
	data.quests.monastery = State.initial()
	data.quests.monastery.merge({"room":"MOFF"},true)
	data.quests.monastery.flags.merge({"134":1,"138":1,"265":1},true)
	data.quests.monastery.locals.Met_Dawn = 1
	if not check(scene.apply_area_handoff(data).is_empty(),"Supplied Julian room/owned flute fixture rejected"): return
	var rooms = scene.monastery
	if not check(not rooms.offer_item("") and not rooms.offer_item("unowned"),"Empty/unowned offer wrongly admitted"): return
	for index in rooms.held.item_count:
		if rooms.held.get_item_metadata(index)==Speech.FLUTE: rooms.held.select(index)
	rooms.give.pressed.emit()
	if not check(rooms.state().conversation.sequence=="MOFF_REFUSE" and rooms.view.clip.name.contains("2237807E") and rooms.view.voice.playing and Speech.FLUTE in scene.carried_collected,"Original refusal GUI/media/item preservation failed"): return
	if not check(str(rooms.held.get_item_metadata(rooms.held.selected))==Speech.FLUTE and rooms.state().flags["265"]==1 and rooms.state().flags["140"]==0 and not rooms.offer_item(Speech.FLUTE),"Refusal changed rune flags or allowed overlap"): return
	rooms.leave_room()
	if not check(rooms.state().room=="MOFF","Refusal allowed early exit"): return
	for frame in range(5): await process_frame
	var saved: Dictionary = rooms.state().conversation.duplicate(true)
	var path := "user://tests/julian_refusal_partial.json"
	if not check(scene.quicksave(path).is_empty(),"Refusal partial save failed"): return
	paused = true
	for frame in range(4): await process_frame
	if not check(same_speech(rooms.state().conversation,saved),"Paused refusal advanced"): return
	paused = false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/julian_wrong_item.png")
	if not await finish(rooms): return
	if not check(rooms.view.clip.name.contains("2237907E") and Speech.FLUTE in scene.carried_collected,"Refusal completion lost second clip or item"): return
	if not check(scene.quickload(path).is_empty() and same_speech(rooms.state().conversation,saved) and rooms.view.voice.playing,"Refusal rollback lost clock or audio"): return
	if not await finish(rooms): return
	# Knowledge is supplied here; its original quest producer is not part of this fixture.
	data = scene.area_handoff()
	data.quests.monastery.globals.GV_KNOWLEDGE_OF_POWER_ORB = 1
	if not check(scene.apply_area_handoff(data).is_empty(),"Power-orb knowledge fixture rejected"): return
	if not check(rooms.offer_item("") and rooms.state().flags["143"]==1 and rooms.state().conversation.sequence=="MOFF_ORB" and rooms.view.clip.name.contains("2237507E"),"Original empty-hand power-orb branch missing"): return
	for frame in range(5): await process_frame
	var orb: Dictionary = scene.area_handoff()
	path = "user://tests/julian_orb_partial.json"
	if not check(scene.quicksave(path).is_empty(),"Orb partial save failed"): return
	for field in ["flag","knowledge","translated"]:
		var bad: Dictionary = orb.duplicate(true)
		if field=="flag": bad.quests.monastery.flags["143"] = 0
		elif field=="knowledge": bad.quests.monastery.globals.GV_KNOWLEDGE_OF_POWER_ORB = 0
		else: bad.quests.monastery.flags["283"] = 1
		if not check(not scene.apply_area_handoff(bad).is_empty() and scene.area_handoff()==orb,"Invalid orb conversation mutated live state: "+field): return
	if not await finish(rooms): return
	if not check(rooms.view.clip.name.contains("2237707E") and not rooms.offer_item("") and Speech.FLUTE in scene.carried_collected,"Orb completion repeated or consumed item"): return
	if not check(scene.quickload(path).is_empty() and same_speech(rooms.state().conversation,orb.quests.monastery.conversation),"Orb partial rollback failed"): return
	if not await finish(rooms): return
	data = scene.area_handoff()
	data.quests.monastery.flags["140"] = 1
	if not check(scene.apply_area_handoff(data).is_empty(),"Completed rune-offer fixture rejected"): return
	if not check(rooms.offer_item(Speech.FLUTE) and not Speech.active(rooms.state().conversation) and Speech.FLUTE in scene.carried_collected,"Post-rune wrong item should be handled without speech/consumption"): return
	var carried: Dictionary = scene.area_handoff()
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	await process_frame
	if not check(hive.apply_area_handoff(carried).is_empty() and hive.monastery_checkpoint==carried.quests.monastery,"Hive lost offer/knowledge state"): return
	await RenderingServer.frame_post_draw
	hive.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	print("PASS original Julian wrong-item/orb media, GUI, ownership, pause, partial disk rollback, one-shot/translation guards, invalid-state atomic rejection and Hive carry; supplied room/knowledge fixture")
	quit()
