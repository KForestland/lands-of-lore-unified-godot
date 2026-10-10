extends SceneTree
const Items = preload("res://scripts/lol2/hive_rune_items.gd")
func _initialize(): run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func run():
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.get_node("Warriors").set_process(false)
	# Supplied lit-room/wax fixture; live Spark lighting remains separate work.
	var state: Dictionary = scene.area_handoff()
	state.inventory.collected.append("hive:item0:Wax")
	state.quests.hive_wax_collected = true
	state.quests.hive_rune_entry.merge({"room":"RUNES","lights":true,"marker642_enabled":true},true)
	if not check(scene.apply_area_handoff(state).is_empty(),"Lit-room fixture rejected"): return
	var entry = scene.runes
	if not check(entry.activate_hotspot(2),"Inscription entry failed"): return
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,entry): return
	if not check(entry.checkpoint.room == "RUNECL","Inscription response did not enter room"): return
	if not check(entry.checkpoint.flag8 and entry.checkpoint.flag286,"Source inscription flags missing"): return
	entry.activate_hotspot(0)
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,entry): return
	if not check("hive:item0:Wax" in scene.carried_inventory.collected,"Empty hand consumed wax"): return
	var wax_index := -1
	for index in range(entry.held.item_count):
		if entry.held.get_item_metadata(index) == "hive:item0:Wax": wax_index = index
	if not check(wax_index > 0,"Held-item selector lacks wax"): return
	entry.held.select(wax_index)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	entry.hotspots[4].gui_input.emit(event)
	if not check(scene.carried_inventory.collected.size() == 1 and Items.valid(scene.carried_inventory.collected[0]),"Wax hotspot did not produce runes"): return
	if not check(scene.player_reward_checkpoint.player.experience == 200 and scene.player_magic_checkpoint.player.experience == 200,"First-copy dual award missing"): return
	if not check(scene.monastery_checkpoint.globals.GV_HAS_RUNES == 1 and scene.wax.collected,"Rune global/world wax state wrong"): return
	var after: Dictionary = scene.area_handoff()
	var path := "user://tests/rune_copy_%d.json" % Time.get_ticks_usec()
	if not check(scene.quicksave(path).is_empty(),"Rune save failed"): return
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,entry): return
	entry.leave()
	entry.leave()
	if not check(scene.open_inventory(),"Inventory unavailable after leaving room"): return
	if not check(scene.inventory.item_list.get_item_text(0) == "Wax runes" and scene.inventory.item_list.get_item_icon(0) != null,"Rune item name/art missing"): return
	scene.inventory.close()
	await process_frame
	if not check(scene.quickload(path).is_empty() and entry.checkpoint.room == "RUNECL","Rune copy save did not resume inscription"): return
	if not check(scene.area_handoff().inventory.collected == after.inventory.collected and scene.monastery_checkpoint.globals.GV_HAS_RUNES == 1,"Rune copy rollback lost item/global"): return
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,entry): return
	entry.leave()
	entry.leave()
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	if not check(jungle.apply_area_handoff(scene.area_handoff()).is_empty(),"Jungle rejected copied runes"): return
	if not check(jungle.area_handoff().inventory.collected == after.inventory.collected and jungle.area_handoff().quests.monastery.globals.GV_HAS_RUNES == 1,"Jungle lost copied runes/global"): return
	jungle.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: lit inscription wax selection/hotspot, dual awards, item art, disk resume and Jungle carry")
	quit()
