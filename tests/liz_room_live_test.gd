extends SceneTree
## Actual Jungle host, village LIZ room (docs/liz-room.md):
## - Entry: VILLAGE hotspot3 (real GUI click) enters LIZ even with flag267 set, while CAN stays refused.
## - Intro: LIZTRAN plays once, flag268 is set at its start; a mid-intro disk save resumes the clip, a pause freezes
##   it, and the first-update cue 2:59 follows. Leaving (callback8) returns to VILLAGE; a re-entry skips the intro.
## - Wax pickup (hotspot0 GUI click):
##   - a full beehive pool and a full inventory each refuse, leaving flag162 clear and the pickup retryable;
##   - success sets 162, grants one beehive-pool "71-Wax" and plays cue 100:2; a second click grants nothing.
##   Hotspots 1..4 (source quips) are not hosted.
## - Saves: flags 162/268 survive disk; legacy saves validate.
## - Consumer: that granted wax, carried by the real Jungle->Hive handoff, becomes runes at the production RUNECL hotspot.
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
const Room = preload("res://scripts/lol2/monastery_quest_state.gd")
const BeeWax = preload("res://scripts/lol2/jungle_beehive_wax.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const Runes = preload("res://scripts/lol2/hive_rune_items.gd")
var scene
var rooms
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func bank() -> Dictionary: return rooms.state()
func click(room: String, at: Vector2) -> bool:
	for hit in rooms.hotspots:
		if hit.get_meta("room") == room and Rect2(hit.position,hit.size).has_point(at) and hit.visible:
			var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
			hit.gui_input.emit(event)
			return true
	return false
func cycle(tag: String) -> bool:
	var path := "user://tests/liz_room_%s.json" % tag
	var before: Variant = JSON.parse_string(JSON.stringify(bank()))
	var items: Array = scene.carried_collected.duplicate()
	if not check(scene.quicksave(path).is_empty(),"Save "+tag): return false
	rooms.advance(0.7)
	var error: String = scene.quickload(path)
	rooms = scene.monastery; rooms.set_process(false); scene.set_physics_process(false)
	DirAccess.remove_absolute(path)
	return check(error.is_empty() and JSON.parse_string(JSON.stringify(bank())) == before and scene.carried_collected == items,"Reload %s: %s" % [tag,error])
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	rooms = scene.monastery; rooms.set_process(false)
	if is_instance_valid(scene.get("bacatta57")): scene.bacatta57.set_physics_process(false); scene.bacatta57.set_process(false)
	if not check(rooms.view.manifest.rooms.has("LIZ"),"LIZ media missing"): return
	var clip: Dictionary = rooms.view.manifest.rooms.LIZ.movies[0]
	if not check(int(clip.frames) == Speech.FRAMES.LIZ[0] and int(clip.audio_samples) == Speech.SAMPLES.LIZ[0],"Intro clip/clock"): return
	for seq in ["LIZ_WAX","LIZ_ENTRY"]:
		var c: Dictionary = rooms.view.manifest.rooms.LIZ.sequences[seq][0]
		if not check(int(c.frames) == 0 and int(c.audio_samples) == Speech.SAMPLES[seq][0],"Cue "+seq): return
	# VILLAGE, then hotspot3 with the tavern closed.
	scene.player.position = Vector3(-1630,32,-3900); rooms.was_inside = false; rooms._process(0.0)
	rooms.advance(1000.0)
	bank().flags["267"] = 1
	if not check(bank().room == "VILLAGE" and not rooms.enter_room("CAN"),"Tavern should be closed"): return
	if not check(click("VILLAGE",Vector2(500,260)) and bank().room == "LIZ" and bank().conversation.sequence == "LIZ" and bank().flags["268"] == 1,"Hotspot3 -> LIZ intro: %s" % [bank().conversation]): return
	if not check(rooms.hotspots.filter(func(h): return h.get_meta("room") == "LIZ").size() == 1,"Quip hotspots hosted"): return
	# Mid-intro save, pause, resume.
	rooms.advance(5.0)
	if not check(cycle("intro") and bank().conversation.sequence == "LIZ" and is_equal_approx(float(bank().conversation.elapsed),5.0),"Mid-intro resume"): return
	rooms.restore()
	paused = true
	rooms._process(2.0)
	paused = false
	if not check(is_equal_approx(float(bank().conversation.elapsed),5.0),"Pause advanced the intro"): return
	if not check(not click("LIZ",Vector2(110,300)) or bank().flags["162"] == 0,"Wax taken during the intro"): return
	rooms.advance(Speech.duration("LIZ",0))
	if not check(bank().conversation.sequence == "LIZ_ENTRY" and Speech.active(bank().conversation),"First-update cue after the intro"): return
	rooms.advance(1000.0)
	if not check(not Speech.active(bank().conversation) and rooms.view.patch.texture == null,"Intro frame left over"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/liz_room.png")
	# Exhausted pool / full inventory: refused, retryable.
	var keep: Array = scene.carried_collected.duplicate()
	for id in BeeWax.POOL: if not id in scene.carried_collected: scene.carried_collected.append(id)
	if not check(click("LIZ",Vector2(110,300)) and bank().flags["162"] == 0 and scene.carried_collected.size() == keep.size() + BeeWax.POOL.size() - keep.filter(func(i): return BeeWax.valid(i)).size(),"Exhausted pool not refused"): return
	scene.carried_collected.assign(keep)
	var filler: Array = Catalog.ids("jungle").filter(func(id): return not id in keep and not BeeWax.valid(id) and not preload("res://scripts/lol2/hive_rune_transaction.gd").is_wax(id))
	while scene.carried_collected.size() < Catalog.MAX_CARRIED: scene.carried_collected.append(filler.pop_back())
	var full: Array = scene.carried_collected.duplicate()
	if not check(click("LIZ",Vector2(110,300)) and bank().flags["162"] == 0 and scene.carried_collected == full,"Full inventory not refused"): return
	scene.carried_collected.assign(keep)
	# Success, then nothing more.
	if not check(click("LIZ",Vector2(110,300)) and bank().flags["162"] == 1 and bank().conversation.sequence == "LIZ_WAX","Wax pickup"): return
	var granted: Array = scene.carried_collected.filter(func(i): return not i in keep)
	if not check(granted.size() == 1 and BeeWax.valid(granted[0]) and preload("res://scripts/lol2/hive_rune_transaction.gd").is_wax(granted[0]),"Granted item: %s" % [granted]): return
	if not check(cycle("wax_cue"),"Mid-cue save"): return
	rooms.advance(1000.0)
	var after: Array = scene.carried_collected.duplicate()
	if not check(not click("LIZ",Vector2(110,300)) or scene.carried_collected == after,"Second pickup"): return
	if not check(scene.carried_collected == after,"Second pickup granted"): return
	# Leave and re-enter: no intro replay.
	rooms.leave_room()
	if not check(bank().room == "VILLAGE","Callback8 did not return to VILLAGE"): return
	if not check(rooms.enter_room("LIZ") and bank().conversation.sequence == "LIZ_ENTRY","Re-entry replayed the intro"): return
	rooms.advance(1000.0); rooms.leave_room(); rooms.leave_room()
	if not check(not rooms.active(),"Rooms not closed"): return
	if not check(cycle("closed") and bank().flags["162"] == 1 and bank().flags["268"] == 1,"Flags lost on disk"): return
	var legacy: Dictionary = Room.initial()
	for key in Room.LIZ_FLAGS: legacy.flags.erase(key)
	if not check(Room.validate(legacy).is_empty(),"Legacy save rejected"): return
	var forged: Dictionary = Room.initial(); forged.room = "LIZ"; forged.conversation = {"sequence":"LIZ_WAX","cursor":0,"elapsed":0.0}
	if not check(not Room.validate(forged).is_empty(),"Wax cue without flag162 accepted"): return
	# Consumer: the granted wax -> runes at the production RUNECL hotspot, after the real Jungle->Hive handoff.
	var wax_id: String = granted[0]
	var handoff: Dictionary = scene.area_handoff()
	scene.queue_free(); await process_frame; await process_frame
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	await process_frame; await physics_frame
	hive.set_development_mode(false); hive.get_node("Warriors").set_process(false)
	handoff.quests.hive_rune_entry = handoff.quests.get("hive_rune_entry",hive.area_handoff().quests.hive_rune_entry)
	handoff.quests.hive_rune_entry.merge({"room":"RUNES","lights":true,"marker642_enabled":true},true)
	var error: String = hive.apply_area_handoff(handoff)
	if not check(error.is_empty() and wax_id in hive.carried_inventory.collected,"Hive handoff: "+error): return
	var entry = hive.runes
	if not check(entry.activate_hotspot(2),"Inscription entry failed"): return
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,entry): return
	var wax_index := -1
	for index in range(entry.held.item_count):
		if entry.held.get_item_metadata(index) == wax_id: wax_index = index
	if not check(wax_index > 0,"Held selector lacks the LIZ wax"): return
	entry.held.select(wax_index)
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	entry.hotspots[4].gui_input.emit(event)
	var carried: Array = hive.carried_inventory.collected
	if not check(not wax_id in carried and carried.any(func(i): return Runes.valid(i)),"LIZ wax did not become runes: %s" % [carried]): return
	hive.queue_free(); await process_frame
	print("PASS liz_room_live: VILLAGE hotspot3 -> LIZ with flag267 set (CAN refused); LIZTRAN once (268 at start), mid-intro disk resume, pause frozen, first-update cue, no leftover frame; pool/inventory full refuse + retry; one beehive wax + cue 100:2, second click nothing; quips not hosted; callback8 -> VILLAGE; re-entry no intro; disk/legacy/forged; granted wax -> runes at production RUNECL after Jungle->Hive handoff.")
	quit()
