extends "res://tests/hive_reaver_amber_live_test.gd"
## Actual Hive host, corridor support pillars 401/426/676/725 (hive_reaver_pillars_source.json, option A):
## - Four original pillar sprites with hit-only bodies (layers 4|8): the player does not collide with them.
## - A real hive_warriors.strike() on pillar401 with the sword still in the wall: pillar state 0->1, HUD line, and the
##   source region365 floor nudge starts the collapse; a repeat hit (state 1->2, then stays 2) adds no second chain.
## - Pre-seal: the sword can still be taken by E right after the hit; production grounded movement escapes through
##   the source portals (between the pillars) to region371; the chain finishes, the later Reaver timer is a no-op,
##   one Reaver, disk reload.
## - Loss: from the pre-hit checkpoint, a hit and the full chain seal the alcove; the sword can no longer be targeted
##   or taken and the sealed state survives a disk reload. A Spark hit on pillar676 counts the same way.
## - Paused/free cursor: a strike is refused and nothing changes. Older saves without pillars load at state 0;
##   invalid pillar values and a collapse with neither the Reaver taken nor a pillar hit are rejected.
## Supplied vantages; only production movement after the pre-seal pickup.
func walk_to(point: Vector3) -> bool:
	for tick in 900:
		await physics_frame
		var offset := Vector2(point.x - hive.player.position.x, point.z - hive.player.position.z)
		if offset.length() < 3: return true
		var delta: float = hive.player.get_physics_process_delta_time()
		var direction: Vector2 = offset.normalized() * minf(1.0, offset.length() / (80.0 * delta))
		hive.move_grounded(Vector3(direction.x, 0, direction.y), delta)
	return check(false, "Grounded escape blocked at %s heading to %s" % [hive.player.position, point])
func aim_pillar(id: String) -> bool:
	var guards = hive.get_node("Warriors")
	var target: Vector3 = owner.pillars[id].body.global_position
	for region in ["366", "365", "367"]:
		for t in [0.0, 0.3, 0.6]:
			var from: Vector3 = center(region).lerp(Vector3(target.x, -235.0, target.z), t)
			stand(from); hive.player.rotation = Vector3.ZERO; hive.camera.rotation = Vector3.ZERO
			await physics_frame
			hive.camera.look_at(target); await physics_frame
			var hit: Dictionary = guards.aimed_hit()
			if not hit.is_empty() and hit.collider == owner.pillars[id].body: return true
	return false
func strike() -> bool:
	var guards = hive.get_node("Warriors")
	guards.cooldown = 0.0
	return guards.strike()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	for i in 10: await process_frame
	hive.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	owner = hive.reaver_amber
	if not check(is_instance_valid(owner) and owner.checkpoint() == State.initial() and owner.pillars.size() == 4, "Owner/pillars missing"): return
	for id in State.PILLARS:
		var body: StaticBody3D = owner.pillars[id].body
		if not check(owner.pillars[id].sprite.visible and body.collision_layer == owner.PILLAR_LAYERS and hive.player.collision_mask & owner.PILLAR_LAYERS == 0, "Pillar %s presentation/layers" % id): return
	# ---- Hit with the sword still in the wall ----
	var pre: Dictionary = owner.checkpoint()
	if not check(await aim_pillar("401"), "No vantage for pillar401"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/hive_reaver_pillar_view.png")
	if not check(strike() and int(owner.state.pillars["401"]) == 1 and owner.state.collapse.movers.has("365:floor") and int(owner.state.reaver.state) == 0, "Pillar hit: %s" % [owner.state]): return
	if not check(hive.interface_hud.hint.text == "The cracked pillar shudders.", "HUD: " + hive.interface_hud.hint.text): return
	var movers: String = JSON.stringify(owner.state.collapse.movers)
	if not check(strike() and int(owner.state.pillars["401"]) == 2 and JSON.stringify(owner.state.collapse.movers) == movers, "Repeat hit re-dispatched: %s" % [owner.state.collapse]): return
	if not check(strike() and int(owner.state.pillars["401"]) == 2, "State2 hit changed state"): return
	var hit_state: Dictionary = owner.checkpoint()
	# Paused (free cursor): refused, unchanged.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not check(not strike() and not owner.hit_pillar("426") and JSON.stringify(owner.checkpoint()) == JSON.stringify(hit_state), "Paused hit changed state"): return
	owner._physics_process(10.0)
	if not check(JSON.stringify(owner.checkpoint()) == JSON.stringify(hit_state), "Paused collapse moved"): return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not cycle("pillars_untaken_moving"): return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# ---- Pre-seal take, then production escape ----
	if not check(not State.alcove_sealed(owner.state) and await view("121", ["365", "366"]), "No pre-seal vantage"): return
	await press_e()
	if not check(State.REAVER in hive.carried_inventory.collected and int(owner.state.reaver.state) == 2 and not State.alcove_sealed(owner.state), "Pre-seal take failed: %s" % [owner.state]): return
	if not await walk_to(center("365")): return
	for region in range(365, 371):
		var shared: Array = []
		for point in owner.source.regions[str(region)].polygon:
			if point in owner.source.regions[str(region + 1)].polygon: shared.append(point)
		if not check(shared.size() == 2, "Expected shared source portal"): return
		if not await walk_to(Vector3((shared[0][0] + shared[1][0]) / 2.0, -235, (shared[0][1] + shared[1][1]) / 2.0)): return
		if not await walk_to(center(str(region + 1))): return
	if not check(owner._player_in("371") and hive.player.is_on_floor(), "Escape did not reach region371"): return
	run_for(60.0)
	var want := {"364:floor":-185.0,"364:ceiling":-185.0,"365:floor":-234.0,"365:ceiling":-234.0,"366:ceiling":-235.0,"367:ceiling":-235.0,"368:ceiling":-235.0,"369:ceiling":-200.0,"370:ceiling":-185.0}
	for key in want:
		if not check(h(key) == want[key], "Final %s = %f" % [key, h(key)]): return
	if not check(owner.state.collapse.finished and owner.state.collapse.movers.is_empty() and float(owner.state.reaver.timer) == 0.0 and hive.carried_inventory.collected.count(State.REAVER) == 1, "Pre-seal chain end: %s" % [owner.state]): return
	# After the end, more hits add nothing.
	var done: String = JSON.stringify(owner.state.collapse)
	if not check(owner.hit_pillar("725") and JSON.stringify(owner.state.collapse) == done and int(owner.state.pillars["725"]) == 1, "Hit after the collapse changed it"): return
	if not cycle("pillars_taken"): return
	# ---- Loss branch: pre-hit checkpoint, hit, full chain, sealed ----
	hive.carried_inventory.collected.erase(State.REAVER)
	if not check(owner.restore(pre).is_empty() and owner.checkpoint() == State.initial(), "Restore pre-hit"): return
	# Spark through the shared collider dispatch (Hive Spark mask 11 reaches layer 8).
	if not check(hive.get("ambush_population") != null and await aim_pillar("676"), "No Spark vantage"): return
	hive.starting_magic.spark()
	if not check(int(owner.state.pillars["676"]) == 1 and owner.state.collapse.movers.has("365:floor") and int(owner.state.reaver.state) == 0, "Spark hit: %s" % [owner.state]): return
	stand(center("371")); await physics_frame
	run_for(60.0)
	if not check(State.alcove_sealed(owner.state) and owner.state.collapse.finished, "Alcove not sealed"): return
	if not check(hive.interface_hud.hint.text == "The alcove has sealed over the sword.", "Missing sealed-sword feedback: " + hive.interface_hud.hint.text): return
	if not check(not State.take_reaver(owner.state, hive.carried_inventory.collected) and not State.REAVER in hive.carried_inventory.collected, "Sealed sword taken"): return
	if not check(not await view("121", ["365", "366"]) and owner.interaction_hint() != "E — Take the sword", "Sealed alcove still targetable"): return
	if not cycle("pillars_sealed"): return
	if not check(State.alcove_sealed(owner.state) and int(owner.state.reaver.state) == 0, "Sealed state lost on reload"): return
	# ---- Saves and validation ----
	var old := State.initial(); old.erase("pillars")
	if not check(State.validate(old).is_empty() and State.canonical(old).pillars == State.initial().pillars, "Older save without pillars"): return
	var bad := State.initial(); bad.pillars["401"] = 3
	if not check(not State.validate(bad).is_empty(), "Pillar state 3 accepted"): return
	bad = State.initial(); bad.collapse.heights["366:ceiling"] = -200.0
	if not check(not State.validate(bad).is_empty(), "Collapse without Reaver or pillar accepted"): return
	bad.pillars["426"] = 1
	if not check(State.validate(bad).is_empty(), "Pillar-started collapse rejected"): return
	print("PASS hive_reaver_pillars_live: 4 original pillars non-blocking hit bodies; real strike 0->1 + HUD + region365 nudge with the sword in the wall, repeat 1->2/2 no second chain, paused refused; pre-seal E take, production escape between the pillars to 371, chain final heights, timer no-op, one Reaver, hit after end no-op, reload; loss branch via Spark: alcove sealed, sword untargetable/untakeable, reload; old saves default pillars 0; validation.")
	quit()
