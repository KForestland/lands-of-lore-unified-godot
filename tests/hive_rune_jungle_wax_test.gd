extends SceneTree
## Rendered: production RUNECL hotspot with Jungle wax row50 carried into the Hive (supplied inventory/lit-room fixture,
## as hive_rune_copy_test). The held Jungle wax becomes runes, the Hive world wax stays uncollected, disk rollback is
## exact, and the runes travel back to the Jungle.
const Items = preload("res://scripts/lol2/hive_rune_items.gd")
const JW := "jungle:item50:Wax"
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
	var state: Dictionary = scene.area_handoff()
	state.inventory.collected.append(JW)
	state.quests.hive_rune_entry.merge({"room":"RUNES","lights":true,"marker642_enabled":true},true)
	var error: String = scene.apply_area_handoff(state)
	if not check(error.is_empty(),"Jungle-wax fixture rejected: "+error): return
	var entry = scene.runes
	if not check(entry.activate_hotspot(2),"Inscription entry failed"): return
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,entry): return
	if not check(entry.checkpoint.room == "RUNECL","Did not enter inscription"): return
	var wax_index := -1
	for index in range(entry.held.item_count):
		if entry.held.get_item_metadata(index) == JW: wax_index = index
	if not check(wax_index > 0 and entry.held.get_item_text(wax_index) == "Wax","Held selector lacks Jungle wax"): return
	entry.held.select(wax_index)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	entry.hotspots[4].gui_input.emit(event)
	var carried: Array = scene.carried_inventory.collected
	if not check(JW not in carried and carried.size() == 1 and Items.valid(carried[0]),"Jungle wax did not become runes: %s"%[carried]): return
	if not check(scene.player_reward_checkpoint.player.experience == 200 and scene.player_magic_checkpoint.player.experience == 200 and scene.monastery_checkpoint.globals.GV_HAS_RUNES == 1,"First-copy reward/global missing"): return
	if not check(not scene.wax.collected,"Hive world wax wrongly marked collected"): return
	var after: Dictionary = scene.area_handoff()
	var path := "user://tests/opus_jungle_wax_%d.json" % Time.get_ticks_usec()
	if not check(scene.quicksave(path).is_empty(),"Save failed"): return
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,entry): return
	entry.leave(); entry.leave()
	if not check(scene.quickload(path).is_empty() and scene.area_handoff().inventory.collected == after.inventory.collected,"Rollback lost runes"): return
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,entry): return
	entry.leave(); entry.leave()
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	if not check(jungle.apply_area_handoff(scene.area_handoff()).is_empty() and jungle.area_handoff().inventory.collected == after.inventory.collected,"Jungle lost runes"): return
	jungle.queue_free(); scene.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("PASS hive_rune_jungle_wax_test: production RUNECL accepts held Jungle wax row50 → runes, first-copy reward, Hive world wax untouched, disk rollback, Jungle transport (supplied fixture)")
	quit()
