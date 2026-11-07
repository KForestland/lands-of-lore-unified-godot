extends SceneTree
## Actual Jungle host + monastery rooms: supplied Dawn local17 (her g29704 wax-runes offer, see jungle_dawn_state_test),
## library entry with Dawn, MLIB message8 exit -> MLIB_EXIT_RUNES (flag192; Dampen charm after movie 666; both
## translation globals and flag266 after 668) -> hall; save/load mid-sequence without duplicate grant; Dawn absent
## afterwards; negative (no runes given) exit; Dampen charm inventory-UI use (consumed, dampened saved, modern
## curse-warning cancel), save/load and validation.
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
const Room = preload("res://scripts/lol2/monastery_quest_state.gd")
const DawnState = preload("res://scripts/lol2/jungle_dawn_state.gd")
var jungle
var rooms
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true; push_error(message); quit(1)
	return ok
func mon() -> Dictionary: return jungle.quest_state.monastery
func cycle(tag: String) -> bool:
	var path := "user://tests/monastery_dawn_dampen_%s.json" % tag
	var error: String = jungle.quicksave(path)
	if not check(error.is_empty(), "Save %s: %s" % [tag, error]): return false
	var before: Dictionary = mon().duplicate(true); var items: Array = jungle.carried_collected.duplicate()
	error = jungle.quickload(path)
	var c: Dictionary = mon().conversation; var b: Dictionary = before.conversation
	var same: bool = str(c.sequence) == str(b.sequence) and int(c.cursor) == int(b.cursor) and absf(float(c.elapsed) - float(b.elapsed)) < 0.001
	for key in ["192","266","184"]: same = same and int(mon().flags.get(key,0)) == int(before.flags.get(key,0))
	return check(error.is_empty() and jungle.carried_collected == items and same and str(mon().room) == str(before.room), "Reload %s: %s conv %s vs %s" % [tag, error, c, b])
func run() -> void:
	jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in 10: await process_frame
	for room in [jungle.magic_shop, jungle.weapon_shop, jungle.departure]:
		if is_instance_valid(room): room.set_process(false)
	jungle.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	rooms = jungle.monastery
	if not check(is_instance_valid(rooms) and rooms.available and is_instance_valid(jungle.dawn), "Monastery rooms/Dawn missing"): return
	# Supplied quest progress: Bacatta met, runes held, library first visit done, Met_Dawn.
	if not jungle.quest_state.has("monastery"): jungle.quest_state.monastery = Room.initial()
	mon().globals.GV_MET_BACATTA = 1; mon().globals.GV_HAS_RUNES = 1
	mon().flags["184"] = 1; mon().locals.Met_Dawn = 1
	# Negative first: runes not given -> Dawn absent from the library, exit goes straight to the hall, no charm.
	if not check(rooms.enter_room("MENT") and rooms.enter_room("MLIB") and not Room.dawn_present(mon()), "Library entry / Dawn presence without runes"): return
	rooms.leave_room()
	if not check(mon().room == "MENT" and not Speech.DAMPEN in jungle.carried_collected and int(mon().flags.get("192",0)) == 0, "Exit without runes"): return
	# Supplied: Dawn's wax-runes offer result (g29704 writes her local17; proven by jungle_dawn_state_test, whose offer
	# needs her present at the outdoor encounter stage). The monastery bank must follow it through the room bridge.
	jungle.dawn.state.locals["17"] = 1
	if not check(rooms.enter_room("MLIB") and int(mon().locals.Gave_Dawn_Runes) == 1 and Room.dawn_present(mon()), "Library with Dawn after runes"): return
	rooms.leave_room()
	if not check(mon().conversation.sequence == "MLIB_EXIT_RUNES" and int(mon().flags["192"]) == 1 and mon().room == "MLIB", "Exit did not start Dawn's translation: %s" % [mon().conversation]): return
	# Through movie 665 (index 2), then save/load mid-sequence (before the grant).
	rooms.advance(Speech.duration("MLIB_EXIT_RUNES",0) + Speech.duration("MLIB_EXIT_RUNES",1) + 0.2)
	if not check(not Speech.DAMPEN in jungle.carried_collected and int(mon().conversation.cursor) == 2, "Early grant / cursor %s" % [mon().conversation]): return
	if not cycle("midsequence"): return
	for i in 4: rooms.advance(Speech.duration("MLIB_EXIT_RUNES",int(mon().conversation.cursor)) + 0.01)
	if not check(jungle.carried_collected.count(Speech.DAMPEN) == 1, "Dampen not granted after 666"): return
	if not cycle("granted"): return
	for i in 3: rooms.advance(Speech.duration("MLIB_EXIT_RUNES",mini(int(mon().conversation.cursor),5)) + 0.01)
	if not check(mon().room == "MENT" and int(mon().globals.GV_RUNES_TRANSLATED) == 1 and int(mon().globals.GV_DAWN_TRANSLATED_RUNES) == 1 and int(mon().flags["266"]) == 1 and jungle.carried_collected.count(Speech.DAMPEN) == 1, "Translation end state: %s" % [mon().globals]): return
	# Dawn now absent; leaving the library again grants nothing.
	if not check(rooms.enter_room("MLIB") and not Room.dawn_present(mon()), "Dawn still present after translation"): return
	rooms.leave_room()
	if not check(mon().room == "MENT" and jungle.carried_collected.count(Speech.DAMPEN) == 1, "Second exit regranted"): return
	rooms.leave_room()
	if not check(mon().room == "", "Leave monastery"): return
	# Dampen charm through the real inventory UI; a pending curse warning is cancelled (modern adapter).
	jungle.curse.set_requests_enabled(true)
	jungle.curse.state.merge({"phase":1,"previous":0,"target":1,"remaining":2.0,"duration":70.0},true)
	if not check(jungle.open_inventory(), "Inventory did not open"): return
	await process_frame
	var inv = jungle.inventory
	var index := -1
	for i in inv.item_list.item_count:
		if str(inv.item_list.get_item_metadata(i)) == Speech.DAMPEN: index = i
	if not check(index >= 0 and inv.item_list.get_item_text(index) == "Dampen charm", "Charm not listed"): return
	inv.select_item(index)
	if not check(inv.use_button.visible and inv.use_button.text == "Use charm", "Use button: %s %s" % [inv.use_button.visible, inv.use_button.text]): return
	inv.use_button.pressed.emit(); await process_frame
	var fx: Dictionary = jungle.item_effects.state()
	if not check(not Speech.DAMPEN in jungle.carried_collected and Speech.DAMPEN in fx.spent and fx.get("dampened",false) and int(jungle.curse.state.phase) == 0, "Charm use: %s curse %s" % [fx, jungle.curse.state]): return
	if is_instance_valid(jungle.inventory): jungle.inventory.queue_free(); await process_frame
	if not cycle("used"): return
	if not check(jungle.item_effects.state().get("dampened",false) and not Speech.DAMPEN in jungle.carried_collected, "Dampened lost on reload"): return
	var Items = preload("res://scripts/lol2/player_item_state.gd")
	var bad: Dictionary = jungle.item_effects.state().duplicate(true); bad.spent.erase(Speech.DAMPEN)
	if not check(not Items.validate(bad, jungle.carried_collected).is_empty(), "Dampened without consumption accepted"): return
	if not check(preload("res://scripts/lol2/act_one_item_names.gd").source_name(Speech.DAMPEN) == "70-Dampen ch" and preload("res://scripts/lol2/item_catalog.gd").use_kind(Speech.DAMPEN) == "dampen_charm", "Dampen identity"): return
	# Full inventory must retain the reward for later, rather than create an invalid 65th item.
	var Catalog=preload("res://scripts/lol2/item_catalog.gd")
	var full: Array=Catalog.ids("jungle").filter(func(id):return id!=Speech.DAMPEN).slice(0,Catalog.MAX_CARRIED)
	if not check(full.size()==Catalog.MAX_CARRIED and Catalog.validate_carried(full,"jungle").is_empty(),"Capacity fixture"):return
	jungle.carried_collected=full.duplicate()
	rooms.grant(Speech.DAMPEN)
	if not check(jungle.carried_collected==full and Speech.DAMPEN in mon().get("pending_items",[]),"Full inventory Dampen must defer without overflow"):return
	if not check(Room.validate(mon()).is_empty(),"Pending charm save state rejected"):return
	jungle.carried_collected.pop_back()
	rooms.grant(Speech.DAMPEN)
	rooms.grant(Speech.DAMPEN)
	if not check(jungle.carried_collected.size()==Catalog.MAX_CARRIED and jungle.carried_collected.count(Speech.DAMPEN)==1 and mon().pending_items.is_empty(),"Deferred charm retry lost or duplicated reward"):return
	print("PASS monastery_dawn_dampen: Dawn local17 (supplied offer result) bridged -> library Dawn; MLIB message8 exit plays 663..668, Dampen charm after 666 (once, incl. mid-sequence reload), translation globals + flag266, Dawn absent after; no-runes exit grants nothing; inventory Use charm consumes, saves dampened, cancels a pending curse warning (modern adapter).")
	quit()
