extends SceneTree
## Actual Jungle host: Aloe plant254 harvested three times by E (one "107-Aloe" each, timers 0..s enabled), busy hand
## and bare plant refused, Aloe use through the item controller then re-harvest of the freed id (spent cleared), disk
## save/reload without farming, live timer clock, native timer order 3->2->1->0; sap tree261 closed (E refused), unarmed
## strike refused, armed LMB strike opens it, three saps, dry, regrowth and closing; barrel1464 three Aloe then broken by
## a strike; capacity refusal is atomic; validation negatives; catalog identities. Supplied vantage and sword.
const State = preload("res://scripts/lol2/jungle_harvest_state.gd")
const Items = preload("res://scripts/lol2/jungle_harvest_items.gd")
var jungle
var harvest
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
func click() -> void:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
	event = InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = false
	Input.parse_input_event(event); Input.flush_buffered_events(); await process_frame
func view(id: String) -> bool:
	var target: Vector3 = harvest.aim_point(id)
	for distance in [60.0, 45.0, 85.0]:
		for step in 16:
			var d := Vector3(cos(step * TAU / 16.0), 0, sin(step * TAU / 16.0))
			jungle.player.global_position = target + d * distance - Vector3(0, jungle.camera.position.y, 0) + Vector3(0, 8, 0)
			jungle.player.rotation = Vector3.ZERO; jungle.camera.rotation = Vector3.ZERO
			jungle.camera.look_at(target); await physics_frame
			if harvest.target() == id: return true
	return false
func cycle(tag: String) -> bool:
	var path := "user://tests/jungle_harvest_%s.json" % tag
	var error: String = jungle.quicksave(path)
	if not check(error.is_empty(), "Save " + tag + ": " + error): return false
	var before: Dictionary = harvest.checkpoint(); var items: Array = jungle.carried_collected.duplicate()
	var spent: Array = jungle.item_effects.state().spent.duplicate()
	error = jungle.quickload(path)
	var same: bool = JSON.stringify(State.canonical(harvest.checkpoint())) == JSON.stringify(State.canonical(before))
	return check(error.is_empty() and same and jungle.carried_collected == items and jungle.item_effects.state().spent == spent, "Reload " + tag + ": " + error)
func use_item(id: String) -> bool:
	if not jungle.open_inventory(): return false
	await process_frame
	var ok: bool = jungle.item_effects.use(id)
	if is_instance_valid(jungle.inventory): jungle.inventory.queue_free()
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return ok
func plant() -> Dictionary: return harvest.state.plants["254"]
func tree() -> Dictionary: return harvest.state.trees["261"]
func run() -> void:
	# Simultaneous timer expiries must all settle before the checkpoint can be saved.
	var boundary: Dictionary=State.initial()
	var bag: Dictionary={"collected":[],"hand":"","spent":[]}
	for i in 3:
		bag.hand=""
		if not check(not State.harvest(boundary,"plant","254",bag).is_empty(),"Boundary harvest fixture"):return
	State.advance(boundary,State.PLANT_PERIOD)
	if not check(State.validate(boundary).is_empty() and int(boundary.plants["254"].state)==2,"Exact simultaneous expiry left invalid zero timers"):return
	jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in 10: await process_frame
	for room in [jungle.monastery, jungle.magic_shop, jungle.weapon_shop, jungle.departure]:
		if is_instance_valid(room): room.set_process(false)
	jungle.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	harvest = jungle.harvest
	if not check(is_instance_valid(harvest) and harvest.checkpoint() == State.initial() and harvest.sprites.size() == 17, "Harvest owner missing/not initial"): return
	if not check(harvest.sprites["254"].texture == harvest.textures.plant[0] and harvest.sprites["261"].texture == harvest.textures.tree[0] and harvest.sprites["1464"].texture == harvest.textures.single[0], "Initial art"): return
	# ---- Aloe plant254 ----
	if not check(await view("254"), "No vantage for plant254"): return
	jungle.hand_item = ""
	if not check(harvest.interaction_hint() == "E — Take aloe", "Hint: " + harvest.interaction_hint()): return
	await process_frame
	if not check(jungle.interface_hud.hint.text == "E — Take aloe", "HUD prompt: " + jungle.interface_hud.hint.text): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/jungle_harvest_plant_view.png")
	var A1 := Items.ALOE_PREFIX + "1"; var A2 := Items.ALOE_PREFIX + "2"; var A3 := Items.ALOE_PREFIX + "3"
	await press_e()
	if not check(jungle.carried_collected.count(A1) == 1 and jungle.hand_item == A1 and int(plant().state) == 1 and plant().timers[0].on and not plant().timers[1].on and harvest.sprites["254"].texture == harvest.textures.plant[1], "First Aloe: %s" % [plant()]): return
	await press_e()
	if not check(not A2 in jungle.carried_collected and int(plant().state) == 1, "Busy hand harvested"): return
	jungle.hand_item = ""; await press_e()
	jungle.hand_item = ""; await press_e()
	if not check(A2 in jungle.carried_collected and A3 in jungle.carried_collected and int(plant().state) == 3 and plant().timers.all(func(t): return t.on) and harvest.sprites["254"].texture == harvest.textures.plant[3], "Three Aloe: %s" % [plant()]): return
	jungle.hand_item = ""
	var bare: Array = jungle.carried_collected.duplicate()
	if not check(harvest.interaction_hint() == "No aloe left on the plant.", "Bare hint: " + harvest.interaction_hint()): return
	await press_e()
	if not check(jungle.carried_collected == bare and int(plant().state) == 3, "Bare plant harvested"): return
	# Aloe use: the existing handler9 adapter (+5 pending heal), id consumed and recorded as spent.
	var pending0: int = int(jungle.item_effects.state().aloe.pending)
	if not check(await use_item(A1) and not A1 in jungle.carried_collected and A1 in jungle.item_effects.state().spent and int(jungle.item_effects.state().aloe.pending) == pending0 + 5, "Aloe use: %s" % [jungle.item_effects.state()]): return
	if not cycle("bare"): return
	if not await view("254"): return
	jungle.hand_item = ""; await press_e()
	if not check(not A1 in jungle.carried_collected and int(plant().state) == 3, "Reload refilled plant"): return
	# Live clock: the owner's own physics process runs the enabled timers.
	var t0: float = float(plant().timers[2].left)
	var until := Time.get_ticks_msec() + 1000
	while Time.get_ticks_msec() < until: await physics_frame
	var t1: float = float(plant().timers[2].left)
	if not check(t1 < t0 - 0.5 and t1 > t0 - 3.0 and float(plant().timers[0].left) <= t1, "Live timer clock %f -> %f" % [t0, t1]): return
	if not cycle("regrowing"): return
	# Timers 0/1 were enabled a few frames before timer2: they are offered first and fail their predicates, timer2 steps
	# 3->2 and stops; within the next period timer1 steps 2->1, then timer0 1->0.
	harvest._physics_process(t1 + 0.01)
	if not check(int(plant().state) == 2 and not plant().timers[2].on and plant().timers[0].on and plant().timers[1].on and harvest.sprites["254"].texture == harvest.textures.plant[2], "Regrow 3->2: %s" % [plant()]): return
	harvest._physics_process(State.PLANT_PERIOD)
	if not check(int(plant().state) == 1 and not plant().timers[1].on, "Regrow 2->1: %s" % [plant()]): return
	harvest._physics_process(State.PLANT_PERIOD)
	if not check(int(plant().state) == 0 and not plant().timers.any(func(t): return t.on), "Regrow 1->0: %s" % [plant()]): return
	# The freed id is reused; harvesting it clears the spent history so the save stays consistent.
	if not await view("254"): return
	jungle.hand_item = ""; await press_e()
	if not check(A1 in jungle.carried_collected and not A1 in jungle.item_effects.state().spent, "Reused Aloe id"): return
	if not check(preload("res://scripts/lol2/player_item_state.gd").validate(jungle.item_effects.state(), jungle.carried_collected).is_empty(), "Item effects inconsistent after reuse"): return
	# ---- Ironwood sap tree261 ----
	jungle.hand_item = ""
	jungle.equipped_item = ""
	if not check(await view("261"), "No vantage for tree261"): return
	if not check(harvest.interaction_hint() == "Strike the tree to tap its sap.", "Closed tree hint: " + harvest.interaction_hint()): return
	var before_tree: Array = jungle.carried_collected.duplicate()
	await press_e()
	if not check(jungle.carried_collected == before_tree and int(tree().state) == 0, "Closed tree harvested"): return
	await click()
	if not check(int(tree().state) == 0, "Unarmed strike opened the tree"): return
	if not jungle.SWORD_ITEM_ID in jungle.carried_collected: jungle.carried_collected.append(jungle.SWORD_ITEM_ID)
	jungle.equipped_item = jungle.SWORD_ITEM_ID
	await click()
	if not check(int(tree().state) == 1 and not tree().timer.on and harvest.sprites["261"].texture == harvest.textures.tree[1], "Armed strike did not open the tree: %s" % [tree()]): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/jungle_harvest_tree_view.png")
	var S1 := Items.SAP_PREFIX + "1"
	for k in 3:
		jungle.hand_item = ""; await press_e()
	if not check(jungle.carried_collected.count(S1) == 1 and (Items.SAP_PREFIX + "3") in jungle.carried_collected and int(tree().state) == 4 and tree().timer.on, "Three saps: %s" % [tree()]): return
	jungle.hand_item = ""
	if not check(harvest.interaction_hint() == "The tree is dry.", "Dry hint: " + harvest.interaction_hint()): return
	await click()
	if not check(int(tree().state) == 4, "Strike changed a tapped tree"): return
	if not cycle("dry"): return
	var left: float = float(tree().timer.left)
	harvest._physics_process(left + 0.01)
	if not check(int(tree().state) == 3 and tree().timer.on, "Sap regrow 4->3: %s" % [tree()]): return
	if not await view("261"): return
	jungle.hand_item = ""; await press_e()
	if not check(int(tree().state) == 4 and (Items.SAP_PREFIX + "4") in jungle.carried_collected, "Sap after regrowth: %s" % [tree()]): return
	harvest._physics_process(State.TREE_PERIOD * 4 + 1.0)
	if not check(int(tree().state) == 0 and not tree().timer.on and harvest.sprites["261"].texture == harvest.textures.tree[0], "Tree closes after regrowth: %s" % [tree()]): return
	# Sap use through the controller (handler98 consumes).
	if not check(await use_item(S1) and not S1 in jungle.carried_collected and S1 in jungle.item_effects.state().spent, "Sap use"): return
	# ---- Barrel1464 ----
	if not check(await view("1464"), "No vantage for barrel1464"): return
	for k in 3:
		jungle.hand_item = ""; await press_e()
	if not check(int(harvest.state.barrel.state) == 3 and harvest.interaction_hint() == "The barrel is empty.", "Barrel Aloe: %s %s" % [harvest.state.barrel, harvest.interaction_hint()]): return
	jungle.hand_item = ""
	await click()
	if not check(int(harvest.state.barrel.state) == 4 and harvest.sprites["1464"].texture == harvest.textures.single[1] and harvest.interaction_hint() == "The barrel is broken.", "Barrel not broken"): return
	# ---- Capacity refusal is atomic ----
	var full: Array = jungle.carried_collected.duplicate()
	var filler: Array = preload("res://scripts/lol2/item_catalog.gd").ids("jungle").filter(func(id): return not id in full and not Items.valid(id))
	while jungle.carried_collected.size() < preload("res://scripts/lol2/item_catalog.gd").MAX_CARRIED: jungle.carried_collected.append(filler.pop_back())
	var snapshot: Dictionary = harvest.checkpoint(); var capped: Array = jungle.carried_collected.duplicate()
	if not await view("255"): return
	jungle.hand_item = ""; await press_e()
	if not check(jungle.carried_collected == capped and harvest.checkpoint() == snapshot, "Harvest beyond MAX_CARRIED"): return
	jungle.carried_collected = full
	# ---- Validation and identities ----
	var bad: Dictionary = State.initial(); bad.plants["254"].state = 1
	if not check(not State.validate(bad).is_empty(), "Plant state without timer accepted"): return
	bad = State.initial(); bad.trees["261"].timer.on = true
	if not check(not State.validate(bad).is_empty(), "Closed tree with running timer accepted"): return
	bad = State.initial(); bad.trees["262"].state = 3
	if not check(not State.validate(bad).is_empty(), "Sap tree state3 without timer accepted"): return
	if not check(not State.validate(JSON.parse_string(JSON.stringify(State.initial())).merged({"extra":1})).is_empty() and State.validate(JSON.parse_string(JSON.stringify(harvest.checkpoint()))).is_empty(), "JSON round trip validation"): return
	var Names = preload("res://scripts/lol2/act_one_item_names.gd")
	var Catalog = preload("res://scripts/lol2/item_catalog.gd")
	for id in Items.pool("aloe"):
		if not check(Names.source_name(id) == "107-Aloe" and Catalog.use_kind(id) == "aloe" and Catalog.admitted(id, "jungle") and not Catalog.admitted(id, "museum") and Catalog.label(id) == "Aloe", "Aloe identity " + id): return
	for id in Items.pool("sap"):
		if not check(Names.source_name(id) == "109-Ironwod sap" and Catalog.use_kind(id) == "ironwood_sap" and Catalog.label(id) == "Ironwood sap", "Sap identity " + id): return
	if not check(not Items.valid(Items.ALOE_PREFIX + "28") and not Items.valid(Items.ALOE_PREFIX + "01") and not Items.valid(Items.SAP_PREFIX + "25"), "Out-of-pool id accepted"): return
	if not check(preload("res://scripts/lol2/jungle_save.gd").validate_inventory(jungle.inventory_state()).is_empty(), "Inventory with harvest items rejected"): return
	if not cycle("final"): return
	print("PASS jungle_harvest_live: plant254 3x E (107-Aloe, timers 0..s), busy/bare refused, Aloe use + reuse clears spent, reload no farming, live clock, timer order 3->2->1->0; tree261 closed/unarmed refused, armed LMB opens, 3 saps, dry, regrow 4->3, closes at 0; sap use; barrel1464 3 Aloe then broken; MAX_CARRIED atomic; validation; identities.")
	quit()
