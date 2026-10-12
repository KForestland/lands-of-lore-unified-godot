extends SceneTree
## Actual Jungle host: beehive prop251 harvested twice by E (source kind4 mode0, one "71-Wax" each), busy hand and
## empty hive refused, disk save/reload without farming, live regrowth clock, full regrowth and next pool id,
## pool exhaustion, wax accepted by the rune inscription semantics, Jungle -> Hive area handoff. Supplied vantage.
const State = preload("res://scripts/lol2/jungle_beehives_state.gd")
const BeeWax = preload("res://scripts/lol2/jungle_beehive_wax.gd")
var jungle
var hives
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed:
		failed = true; push_error(message); quit(1)
	return ok
func press_e() -> void:
	var event := InputEventKey.new(); event.keycode = KEY_E; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
	event = InputEventKey.new(); event.keycode = KEY_E; event.pressed = false
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func view(id: String) -> bool:
	var target: Vector3 = hives.aim_point(id)
	for distance in [70.0, 50.0, 90.0]:
		for step in 16:
			var d := Vector3(cos(step * TAU / 16.0), 0, sin(step * TAU / 16.0))
			jungle.player.global_position = target + d * distance - Vector3(0, jungle.camera.position.y, 0) + Vector3(0, 10, 0)
			jungle.player.rotation = Vector3.ZERO; jungle.camera.rotation = Vector3.ZERO
			jungle.camera.look_at(target); await physics_frame
			if hives.target() == id: return true
	return false
func cycle(tag: String) -> bool:
	var path := "user://tests/jungle_beehives_%s.json" % tag
	var error: String = jungle.quicksave(path)
	if not check(error.is_empty(), "Save " + tag + ": " + error): return false
	var before: Dictionary = hives.checkpoint(); var items: Array = jungle.carried_collected.duplicate()
	error = jungle.quickload(path)
	return check(error.is_empty() and hives.checkpoint() == before and jungle.carried_collected == items, "Reload " + tag + ": " + error)
func run() -> void:
	jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in 10: await process_frame
	for room in [jungle.monastery, jungle.magic_shop, jungle.weapon_shop, jungle.departure]:
		if is_instance_valid(room): room.set_process(false)
	jungle.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hives = jungle.beehives
	if not check(is_instance_valid(hives) and hives.checkpoint() == State.initial(), "Beehive owner missing/not initial"): return
	if not check(hives.sprites["251"].texture == hives.textures[0] and hives.sprites["252"].visible, "Initial hive art"): return
	if not check(await view("251"), "No vantage for hive251"): return
	jungle.hand_item = ""
	if not check(hives.interaction_hint() == "E — Take wax", "Hint: " + hives.interaction_hint()): return
	await process_frame
	if not check(jungle.interface_hud.hint.text == "E — Take wax", "HUD prompt: " + jungle.interface_hud.hint.text): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/jungle_beehive_view.png")
	await press_e()
	if not check(jungle.carried_collected.count(BeeWax.POOL[0]) == 1 and jungle.hand_item == BeeWax.POOL[0] and int(hives.state.hives["251"].fullness) == 1 and hives.sprites["251"].texture == hives.textures[1], "First harvest"): return
	await press_e()
	if not check(jungle.carried_collected.count(BeeWax.POOL[1]) == 0 and int(hives.state.hives["251"].fullness) == 1, "Busy hand harvested"): return
	jungle.hand_item = ""
	await press_e()
	if not check(jungle.carried_collected.count(BeeWax.POOL[1]) == 1 and int(hives.state.hives["251"].fullness) == 2, "Second harvest"): return
	jungle.hand_item = ""
	var before_empty: Array = jungle.carried_collected.duplicate()
	if not check(hives.interaction_hint() == "The hive is empty.", "Empty hint: " + hives.interaction_hint()): return
	await press_e()
	if not check(jungle.carried_collected == before_empty and int(hives.state.hives["251"].fullness) == 2, "Empty hive harvested"): return
	# No farming by reload.
	if not cycle("empty"): return
	if not await view("251"): return
	jungle.hand_item = ""
	await press_e()
	if not check(jungle.carried_collected == before_empty, "Reload refilled hive"): return
	# Live regrowth clock: the owner's own physics process advances the timer.
	var t0: float = float(hives.state.hives["251"].timer)
	var until := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until: await physics_frame
	var t1: float = float(hives.state.hives["251"].timer)
	if not check(t1 < t0 - 0.5 and t1 > t0 - 3.0, "Live regrowth clock %f -> %f" % [t0, t1]): return
	if not cycle("regrowing"): return
	hives._physics_process(t1 + 0.01)
	if not check(int(hives.state.hives["251"].fullness) == 1 and absf(float(hives.state.hives["251"].timer) - State.REGROW) < 0.02 and hives.sprites["251"].texture == hives.textures[1], "Regrow stage 2->1"): return
	hives._physics_process(State.REGROW)
	if not check(int(hives.state.hives["251"].fullness) == 0 and float(hives.state.hives["251"].timer) == 0, "Regrow stage 1->0"): return
	if not await view("251"): return
	jungle.hand_item = ""
	await press_e()
	if not check(jungle.carried_collected.count(BeeWax.POOL[2]) == 1, "Next pool id after regrowth"): return
	# Pool exhaustion: other hives fill the pool; then a harvest is refused without changing state.
	for id in ["252","253"]:
		for k in 2:
			jungle.hand_item = ""
			var inv := {"collected":jungle.carried_collected,"hand":""}
			State.harvest(hives.state, id, inv)
	jungle.hand_item = ""
	hives.state.hives["251"] = {"fullness":0,"timer":0.0}
	var full: Array = jungle.carried_collected.duplicate()
	if not check(BeeWax.POOL.all(func(w): return w in full), "Pool not full"): return
	if not await view("251"): return
	await press_e()
	if not check(jungle.carried_collected == full and int(hives.state.hives["251"].fullness) == 0, "Exhausted pool harvested"): return
	# Wax semantics and inventory validation.
	var Tx = preload("res://scripts/lol2/hive_rune_transaction.gd")
	var Names = preload("res://scripts/lol2/act_one_item_names.gd")
	var Catalog = preload("res://scripts/lol2/item_catalog.gd")
	for w in BeeWax.POOL:
		if not check(Tx.is_wax(w) and Names.source_name(w) == "71-Wax" and Catalog.admitted(w, "jungle") and not Catalog.admitted(w, "museum"), "Wax identity " + w): return
	if not check(preload("res://scripts/lol2/jungle_save.gd").validate_inventory(jungle.inventory_state()).is_empty(), "Inventory with wax rejected"): return
	if not check(not State.validate({"version":1,"hives":{"251":{"fullness":0,"timer":5.0},"252":{"fullness":0,"timer":0},"253":{"fullness":0,"timer":0}}}).is_empty(), "Full regrowing hive accepted"): return
	if not check(not State.validate({"version":1,"hives":{"251":{"fullness":2,"timer":0},"252":{"fullness":0,"timer":0},"253":{"fullness":0,"timer":0}}}).is_empty(), "Empty hive without timer accepted"): return
	# A free wax pool id does not allow exceeding the shared inventory capacity.
	var capacity_items: Array=Catalog.ids("jungle").filter(func(id):return not BeeWax.valid(id)).slice(0,Catalog.MAX_CARRIED)
	if not check(capacity_items.size()==Catalog.MAX_CARRIED and Catalog.validate_carried(capacity_items,"jungle").is_empty(),"Full inventory fixture"):return
	var capacity_inventory: Dictionary={"collected":capacity_items.duplicate(),"hand":""}
	var capacity_state: Dictionary=State.initial()
	if not check(State.harvest(capacity_state,"251",capacity_inventory).is_empty() and capacity_state==State.initial() and capacity_inventory.collected==capacity_items,"Full inventory harvest must refuse atomically"):return
	# Jungle -> Hive handoff with wax.
	var handoff: Dictionary = jungle.area_handoff()
	jungle.queue_free(); await process_frame; await process_frame
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	for i in 3: await process_frame
	var error: String = hive.apply_area_handoff(JSON.parse_string(JSON.stringify(handoff, "", true, true)))
	if not check(error.is_empty() and BeeWax.POOL[0] in hive.carried_inventory.collected, "Hive handoff with wax: " + error): return
	print("PASS jungle_beehives_live: hive251 two E harvests (one 71-Wax each), busy hand/empty refused, reload no farming, live regrowth clock, regrowth 2->1->0 and next pool id, exhaustion refused, wax = inscription wax/71-Wax/Jungle-scope, Jungle->Hive handoff.")
	quit()
