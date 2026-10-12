extends SceneTree
const Speech = preload("res://scripts/lol2/hive_rune_speech.gd")
const Wait = preload("res://tests/rune_speech_wait.gd")
func _initialize(): run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func run():
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.get_node("Warriors").set_process(false)
	var state: Dictionary = scene.area_handoff()
	state.inventory.collected.append("hive:item0:Wax")
	state.quests.hive_wax_collected = true
	state.quests.hive_rune_entry.merge({"room":"RUNES","marker642_enabled":true},true)
	if not check(scene.apply_area_handoff(state).is_empty(),"Dark rune fixture rejected"): return
	var entry = scene.runes
	if not check(entry.activate_hotspot(2) and entry.checkpoint.speech_key=="2:26" and not entry.checkpoint.flag8,"Dark room response/source ordering missing"): return
	if not check(entry.view.voice.playing and is_equal_approx(entry.view.voice.stream.get_length(),Speech.media()["2:26"].duration),"Original response audio not playing"): return
	for tick in range(5): await process_frame
	var elapsed: float = entry.checkpoint.speech_elapsed
	paused = true
	for tick in range(5): await process_frame
	if not check(entry.checkpoint.speech_elapsed==elapsed,"Paused rune speech advanced"): return
	paused = false
	var path := "user://tests/rune_speech_partial.json"
	if not check(scene.quicksave(path).is_empty(),"Partial speech save failed"): return
	if not check(not entry.activate_hotspot(4),"Speech allows overlapping hotspot"): return
	entry.leave()
	if not check(entry.checkpoint.room=="RUNES","Speech allowed premature room exit"): return
	if not await Wait.settle(self,entry): return
	if not check(scene.quickload(path).is_empty() and entry.checkpoint.speech_key=="2:26" and is_equal_approx(entry.checkpoint.speech_elapsed,elapsed) and entry.view.voice.playing,"Partial speech did not restore audio/clock"): return
	if not await Wait.settle(self,entry): return
	state = scene.area_handoff()
	state.quests.hive_rune_entry.lights = true
	if not check(scene.apply_area_handoff(state).is_empty(),"Lit fixture rejected"): return
	entry.activate_hotspot(3)
	var response: String = entry.checkpoint.speech_key
	if not check(response.begins_with("2:") and int(response.get_slice(":",1)) in Speech.RESPONSE_LINES,"Third hotspot did not use source response pool"): return
	if not await Wait.settle(self,entry): return
	var history: int = entry.checkpoint.response_mask
	var seed: int = entry.checkpoint.response_seed
	entry.activate_hotspot(3)
	if not check(not entry.busy() and entry.checkpoint.response_mask==history and entry.checkpoint.response_seed==seed,"Response repeat guard failed"): return
	if not check(entry.activate_hotspot(2) and entry.checkpoint.room=="RUNES" and entry.checkpoint.flag8 and not entry.checkpoint.flag286 and entry.checkpoint.speech_key=="2:64","First inscription opened before original response"): return
	for tick in range(5): await process_frame
	if not check(scene.quicksave(path).is_empty(),"Pending inscription save failed"): return
	if not await Wait.settle(self,entry): return
	if not check(entry.checkpoint.room=="RUNECL" and entry.checkpoint.flag286,"First response did not finish inscription transition"): return
	if not check(scene.quickload(path).is_empty() and entry.checkpoint.room=="RUNES" and entry.checkpoint.speech_next=="inscription","Pending inscription rollback lost continuation"): return
	if not await Wait.settle(self,entry): return
	entry.activate_hotspot(0)
	if not check(entry.checkpoint.speech_key=="2:51" and "hive:item0:Wax" in scene.carried_inventory.collected,"Empty-hand audio consumed wax"): return
	if not await Wait.settle(self,entry): return
	for index in entry.held.item_count:
		if entry.held.get_item_metadata(index)=="hive:item0:Wax": entry.held.select(index)
	entry.activate_hotspot(0)
	if not check(entry.checkpoint.speech_key=="2:66" and "hive:item0:Wax" not in scene.carried_inventory.collected and scene.player_magic_checkpoint.player.experience==200,"Copy acknowledgment must follow item/reward effects"): return
	if not check(scene.quicksave(path).is_empty(),"Copy acknowledgment save failed"): return
	if not await Wait.settle(self,entry): return
	if not check(scene.quickload(path).is_empty() and entry.checkpoint.speech_key=="2:66" and scene.player_magic_checkpoint.player.experience==200,"Acknowledgment rollback duplicated/lost reward"): return
	if not await Wait.settle(self,entry): return
	for index in entry.held.item_count:
		if preload("res://scripts/lol2/hive_rune_items.gd").valid(entry.held.get_item_metadata(index)): entry.held.select(index)
	entry.activate_hotspot(0)
	if not check(entry.checkpoint.speech_key=="2:35","Wrong-item response missing"): return
	if not await Wait.settle(self,entry): return
	if not check(not entry.activate_hotspot(1) and entry.checkpoint.speech_key=="2:62","Lower inscription response/false return mismatch"): return
	var before: Dictionary = scene.area_handoff()
	for field in ["speech_key","speech_elapsed","speech_next","response_mask"]:
		var bad: Dictionary = before.duplicate(true)
		bad.quests.hive_rune_entry[field] = {"speech_key":"2:999","speech_elapsed":-1,"speech_next":"inscription","response_mask":512}[field]
		if not check(not scene.apply_area_handoff(bad).is_empty() and scene.area_handoff()==before,"Malformed speech mutated live state: "+field): return
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	var carried: Dictionary = scene.area_handoff()
	if not check(jungle.apply_area_handoff(carried).is_empty() and jungle.area_handoff().quests.hive_rune_entry==carried.quests.hive_rune_entry,"Speech/history handoff lost state"): return
	if not await Wait.settle(self,entry): return
	entry.leave()
	if not check(entry.checkpoint.response_mask==(history&255),"RUNES setup did not reset only trigger bits"): return
	entry.activate_hotspot(3)
	if not check(entry.checkpoint.speech_key!=response,"Response history repeated on next visit"): return
	if not await Wait.settle(self,entry): return
	if not check(entry.activate_hotspot(2) and entry.checkpoint.room=="RUNECL" and not entry.busy(),"Repeat inscription replayed first-use response"): return
	await RenderingServer.frame_post_draw
	jungle.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	print("PASS original rune audio, first/repeat ordering, response history, pause, partial speech/continuation/reward disk rollback, malformed rejection and Jungle carry; normal-rate supplied room fixture")
	quit()
