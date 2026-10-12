extends SceneTree
const Stone = preload("res://scripts/lol2/hive_ancient_stone.gd")
const State = preload("res://scripts/lol2/hive_rune_entry_state.gd")
var save_path := "user://tests/ancient_stone_partial.json"
func _initialize(): run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
func wait_for_grant(entry) -> bool:
	for tick in range(600):
		await process_frame
		if entry.checkpoint.flag7 and not entry.busy(): return true
	return check(false,"Stone film did not finish naturally")
func run():
	Engine.time_scale = 4
	var legacy := State.initial()
	for field in ["flag7","stone_playing","stone_elapsed"]: legacy.erase(field)
	if not check(State.validate(legacy).is_empty(),"Legacy rune state rejected"): return
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.get_node("Warriors").set_process(false)
	var state: Dictionary = scene.area_handoff()
	state.quests.hive_rune_entry.merge({"room":"RUNES","marker642_enabled":true},true)
	if not check(scene.apply_area_handoff(state).is_empty(),"Dark-room fixture rejected"): return
	var entry = scene.runes
	entry.activate_hotspot(4)
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,entry): return
	if not check(not entry.checkpoint.stone_playing and Stone.ITEM not in scene.carried_inventory.collected,"Unlit room granted stone"): return
	state = scene.area_handoff()
	state.quests.hive_rune_entry.lights = true
	if not check(scene.apply_area_handoff(state).is_empty(),"Lit-room fixture rejected"): return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	entry.hotspots[3].gui_input.emit(event)
	if not check(entry.checkpoint.stone_playing and not entry.checkpoint.flag7 and Stone.ITEM not in scene.carried_inventory.collected,"Stone was granted before pickup movie"): return
	if not check(not entry.activate_hotspot(2) and not entry.activate_hotspot(4),"Stone movie allowed overlapping hotspot action"): return
	entry.leave()
	if not check(entry.checkpoint.room == "RUNES","Stone movie allowed early room exit"): return
	for tick in range(8): await process_frame
	var partial: float = entry.checkpoint.stone_elapsed
	if not check(partial > 0 and partial < Stone.DURATION,"No partial pickup movie progress"): return
	paused = true
	for tick in range(5): await process_frame
	if not check(entry.checkpoint.stone_elapsed == partial,"Paused stone movie advanced"): return
	paused = false
	if not check(scene.quicksave(save_path).is_empty(),"Partial stone disk save failed"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/ancient_stone_pickup.png")
	if not await wait_for_grant(entry): return
	if not check(scene.carried_inventory.collected.count(Stone.ITEM) == 1 and not entry.checkpoint.stone_playing and entry.view.visual.is_empty(),"Stone item/flag/overlay final state wrong"): return
	if not check(not entry.activate_hotspot(4),"Stone can be collected twice"): return
	if not check(scene.quickload(save_path).is_empty(),"Partial stone rollback failed"): return
	if not check(entry.checkpoint.stone_playing and is_equal_approx(entry.checkpoint.stone_elapsed,partial) and not entry.checkpoint.flag7 and Stone.ITEM not in scene.carried_inventory.collected,"Partial rollback granted stone or lost clock"): return
	if not check(entry.view.last_frame == int(partial*15),"Partial movie visual did not seek"): return
	if not await wait_for_grant(entry): return
	if not check(scene.carried_inventory.collected.count(Stone.ITEM)==1,"Rollback duplicated pickup"): return
	var before: Dictionary = scene.area_handoff()
	var bad: Dictionary = before.duplicate(true)
	bad.quests.hive_rune_entry.stone_playing = true
	if not check(not scene.apply_area_handoff(bad).is_empty() and scene.area_handoff()==before,"Inconsistent pickup accepted or mutated live state"): return
	bad = before.duplicate(true)
	bad.quests.hive_rune_entry.stone_elapsed = -1
	if not check(not scene.apply_area_handoff(bad).is_empty() and scene.area_handoff()==before,"Negative movie time accepted or mutated state"): return
	entry.leave()
	if not check(scene.open_inventory(),"Stone inventory unavailable"): return
	var found := false
	for index in scene.inventory.item_list.item_count:
		if scene.inventory.item_list.get_item_text(index)=="Ancients’ Stone":
			found = scene.inventory.item_list.get_item_icon(index)!=null
	if not check(found,"Original Ancient Stone inventory art/name missing"): return
	scene.inventory.close()
	await process_frame
	var final_path := "user://tests/ancient_stone_complete.json"
	if not check(scene.quicksave(final_path).is_empty() and scene.quickload(final_path).is_empty(),"Final stone save/restore failed"): return
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	if not check(jungle.apply_area_handoff(scene.area_handoff()).is_empty(),"Jungle rejects stone"): return
	var carried: Dictionary = jungle.area_handoff()
	if not check(Stone.ITEM in carried.inventory.collected and carried.quests.hive_rune_entry.flag7,"Jungle lost stone/one-shot flag"): return
	if not check(scene.apply_area_handoff(carried).is_empty() and not scene.runes.activate_hotspot(4),"Hive return allowed duplicate grant"): return
	await RenderingServer.frame_post_draw
	jungle.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	print("PASS original Ancient Stone hotspot/film, delayed one-shot grant, pause, partial/final disk rollback, icon, Jungle carry and invalid-state atomic rejection; supplied lit-room fixture")
	quit()
