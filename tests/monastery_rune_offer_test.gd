extends SceneTree
var broken_route := "--broken-sword" in OS.get_cmdline_user_args()
var offers_route := "--julian-offers" in OS.get_cmdline_user_args()
var speech_route := "--rune-speech" in OS.get_cmdline_user_args()
var stone_route := "--ancient-stone" in OS.get_cmdline_user_args()
var spell_route := "--starting-spells" in OS.get_cmdline_user_args()
var cave_chain := "--earned-cave-chain" in OS.get_cmdline_user_args()
func chain_save(path: String) -> String:
	if broken_route: return "user://tests/act1_broken_orb_monastery.json" if "runes_monastery_return" in path else path.replace("act1_","act1_broken_")
	if "--weapon-shop" in OS.get_cmdline_user_args(): return "user://tests/act1_shop_orb_monastery.json" if "runes_monastery_return" in path else path.replace("act1_","act1_shop_")
	if offers_route: return path.replace("act1_","act1_magic_speech_" if "runes_monastery_return" in path else "act1_magic_offers_")
	if speech_route and "wax_upper_return" not in path: return path.replace("act1_","act1_magic_speech_")
	if stone_route and "wax_upper_return" not in path: return path.replace("act1_","act1_magic_stone_")
	return path.replace("act1_","act1_magic_") if spell_route else (path.replace("act1_","act1_cave_") if cave_chain else path)
func chain_proof(path: String) -> String:
	if broken_route: return "res://docs/broken-magic-knowledge-walk-checks.json" if "hive-earned-rune-return" in path else path.replace("res://docs/","res://docs/broken-")
	if "--weapon-shop" in OS.get_cmdline_user_args(): return "res://docs/weapon-shop-earned-walk-checks.json" if "hive-earned-rune-return" in path else path.replace("res://docs/","res://docs/shop-")
	if offers_route: return path.replace("res://docs/","res://docs/magic-speech-" if "hive-earned-rune-return" in path else "res://docs/magic-offers-")
	if speech_route and "hive-wax-return-checks" not in path: return path.replace("res://docs/","res://docs/magic-speech-")
	if stone_route and "hive-wax-return-checks" not in path: return path.replace("res://docs/","res://docs/magic-stone-")
	return path.replace("res://docs/","res://docs/magic-") if spell_route else (path.replace("res://docs/","res://docs/cave-") if cave_chain else path)
const Items = preload("res://scripts/lol2/hive_rune_items.gd")
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
func _initialize(): run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message); quit(1)
	return ok
func run():
	Engine.time_scale = 4
	var scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var input_path := chain_save("user://tests/act1_runes_monastery_return.json")
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(chain_proof("res://docs/hive-earned-rune-return-checks.json")))
	if not check(FileAccess.get_sha256(input_path) == proof.output_sha256 and scene.quickload(input_path).is_empty(),"Earned monastery rune checkpoint mismatch"): return
	var rooms = scene.monastery
	rooms.set_process(false)
	if not check(((broken_route or "--weapon-shop" in OS.get_cmdline_user_args()) and rooms.state().room == "MOFF") or rooms.enter_room("MOFF"),"Earned runes could not enter Julian office"): return
	rooms.set_process(true)
	for frame in range(2400):
		await process_frame
		if not Speech.active(rooms.state().conversation): break
	if not check(not Speech.active(rooms.state().conversation),"Original rune-entry speech did not finish"): return
	rooms.set_process(false)
	if not check(rooms.offer_item(Speech.FLUTE) and Speech.FLUTE in scene.carried_collected and rooms.state().conversation.sequence == "MOFF_REFUSE","Wrong-item response missing or item consumed"): return
	rooms.set_process(true)
	for frame in range(1800):
		await process_frame
		if not Speech.active(rooms.state().conversation): break
	if not check(not Speech.active(rooms.state().conversation),"Original refusal did not finish naturally"): return
	rooms.set_process(false)
	var index := -1
	var rune := ""
	for i in range(rooms.held.item_count):
		if Items.valid(rooms.held.get_item_metadata(i)):
			index = i
			rune = rooms.held.get_item_metadata(i)
	if not check(index>0,"Rune copy missing from office selector"): return
	rooms.held.select(index)
	rooms.give.pressed.emit()
	var state: Dictionary = rooms.state()
	if not check(not rune in scene.carried_collected and state.flags["140"]==1 and state.conversation.sequence=="MOFF_RUNES" and state.globals.GV_RUNES_TRANSLATED==0,"Rune offer consumed/started incorrectly"): return
	if not check(rooms.view.clip.name.contains("2255007E") and not rooms.view.clip.audio.is_empty(),"Original first translation movie/audio not bound"): return
	if not check(not rooms.offer_item(Speech.FLUTE),"Speaking room accepted item"): return
	rooms.advance(Speech.duration("MOFF_RUNES",0)+0.25)
	var before: Dictionary = scene.area_handoff()
	var path := "user://tests/monastery_rune_partial.json"
	if not check(scene.quicksave(path).is_empty(),"Partial translation save failed"): return
	rooms.advance(1000)
	if not check(state.globals.GV_RUNES_TRANSLATED==1 and state.flags["141"]==1 and state.flags["142"]==1 and state.flags["283"]==1,"Translation final effects missing"): return
	if not check(scene.quickload(path).is_empty(),"Partial translation load failed"): return
	rooms.set_process(false)
	state = rooms.state()
	if not check(state.conversation.cursor==1 and is_equal_approx(state.conversation.elapsed,0.25) and state.globals.GV_RUNES_TRANSLATED==0 and not rune in scene.carried_collected,"Partial rollback lost clock/item/effects"): return
	var invalid: Dictionary = before.duplicate(true)
	invalid.quests.monastery.flags["140"] = 0
	if not check(not scene.apply_area_handoff(invalid).is_empty() and scene.area_handoff().inventory.collected==before.inventory.collected,"Invalid translation checkpoint accepted"): return
	rooms.set_process(true)
	for frame in range(2400):
		await process_frame
		if not Speech.active(rooms.state().conversation): break
	if not check(rooms.state().globals.GV_RUNES_TRANSLATED==1 and not Speech.active(rooms.state().conversation),"Natural translation clock did not finish"): return
	var final_inventory: Array = scene.carried_collected.duplicate()
	if not check(Speech.FLUTE in final_inventory and final_inventory==before.inventory.collected,"Translation lost unrelated earned items"): return
	var output_path := chain_save("user://tests/act1_runes_translated.json")
	if not check(scene.quicksave(output_path).is_empty(),"Translated checkpoint save failed"): return
	rooms.leave_room()
	if not check(scene.quickload(output_path).is_empty() and rooms.state().globals.GV_RUNES_TRANSLATED==1 and scene.carried_collected==final_inventory,"Completed translation save lost effects"): return
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	await process_frame
	await physics_frame
	await process_frame
	if not check(hive.apply_area_handoff(scene.area_handoff()).is_empty() and hive.monastery_checkpoint.globals.GV_RUNES_TRANSLATED==1,"Hive rejected/lost translated rune state"): return
	var report := {"passed":true,"input_sha256":FileAccess.get_sha256(input_path),"output_sha256":FileAccess.get_sha256(output_path),"scope":"Earned monastery return checkpoint; office admission, held rune GUI offer, original13 clips/audio, source flags and delayed translation, partial disk rollback, natural playback completion, final disk resume and Hive carry. Original wrong-item response finishes before rune offer; other office branches remain separately scoped."}
	var file := FileAccess.open(chain_proof("res://docs/monastery-rune-offer-live-checks.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	hive.queue_free()
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: earned runes offered to Julian, original translation playback, partial/final saves and Hive carry")
	quit()
