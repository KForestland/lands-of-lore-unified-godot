extends SceneTree
## Actual Hive host: control121 Reaver taken by E (sword -> empty wall, one "18-Reaver of GO"), repeat refused, reload
## mid-timer, the source collapse chain (365 floor nudge -> alcove floor/ceiling -> corridor ceilings 365..370 -> end)
## with final heights and collision; a player standing in region367 blocks its ceiling (chain waits) until they leave;
## control123 Amber three harvests, spent refusal, regrowth to state2 and one more; capacity refusal; validation;
## identities (Reaver weapon, Amber = Kityara's "110-Amber" offer identity); Hive -> Jungle handoff. Supplied vantage.
const State = preload("res://scripts/lol2/hive_reaver_amber_state.gd")
const Items = preload("res://scripts/lol2/hive_amber_items.gd")
var hive
var owner
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
func center(region: String) -> Vector3:
	var sum := Vector2.ZERO
	var poly: Array = owner.source.regions[region].polygon
	for p in poly: sum += Vector2(float(p[0]), float(p[1]))
	sum /= poly.size()
	return Vector3(sum.x, -235.0, sum.y)
func stand(point: Vector3) -> void:
	hive.player.global_position = point + Vector3(0, 32, 0)
	hive.player.velocity = Vector3.ZERO
func view(key: String, regions: Array) -> bool:
	var target: Vector3 = owner.aim_point(key)
	for region in regions:
		for t in [0.5, 0.25, 0.75]:
			var from: Vector3 = center(region).lerp(Vector3(target.x, -235.0, target.z), t)
			stand(from)
			hive.player.rotation = Vector3.ZERO; hive.camera.rotation = Vector3.ZERO
			await physics_frame
			hive.camera.look_at(target); await physics_frame
			if owner.target() == key: return true
	return false
## In front of the Amber panel: along its face normal, on the floor.
func amber_view() -> bool:
	var face: Dictionary = owner.source.controls["123"].faces[0]
	var p0 := Vector3(face.points[0][0], face.points[0][1], face.points[0][2])
	var p1 := Vector3(face.points[1][0], face.points[1][1], face.points[1][2])
	var p2 := Vector3(face.points[2][0], face.points[2][1], face.points[2][2])
	var normal := (p1 - p0).cross(p2 - p0).normalized()
	var target: Vector3 = owner.aim_point("123")
	# The vein faces into region379 along -normal (the +normal side is outside the cave shell).
	for side in [-1.0]:
		for distance in [50.0, 35.0, 70.0]:
			var spot: Vector3 = target + normal * side * distance
			stand(Vector3(spot.x, -235.0, spot.z))
			hive.player.rotation = Vector3.ZERO; hive.camera.rotation = Vector3.ZERO
			await physics_frame
			hive.camera.look_at(target); await physics_frame
			if owner.target() == "123": return true
	return false
func cycle(tag: String) -> bool:
	var path := "user://tests/hive_reaver_amber_%s.json" % tag
	var error: String = hive.quicksave(path)
	if not check(error.is_empty(), "Save " + tag + ": " + error): return false
	var before: Dictionary = owner.checkpoint(); var items: Array = hive.carried_inventory.collected.duplicate()
	error = hive.quickload(path)
	hive.set_physics_process(false)
	var same: bool = JSON.stringify(State.canonical(owner.checkpoint())) == JSON.stringify(State.canonical(before))
	return check(error.is_empty() and same and hive.carried_inventory.collected == items, "Reload %s: %s %s vs %s" % [tag, error, owner.checkpoint(), before])
func run_for(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		owner._physics_process(0.05); t += 0.05
func h(key: String) -> float: return State.height(owner.state, int(key.get_slice(":", 0)), key.get_slice(":", 1))
func run() -> void:
	hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive); current_scene = hive
	for i in 10: await process_frame
	hive.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	owner = hive.reaver_amber
	if not check(is_instance_valid(owner) and owner.checkpoint() == State.initial(), "Reaver/Amber owner missing/not initial"): return
	var sword_parts: Array = owner.controls["121"].parts
	if not check(sword_parts.filter(func(p): return p.mesh.visible).all(func(p): return int(p.mask) & 1), "Initial sword art"): return
	# ---- Reaver ----
	if not check(await view("121", ["365","366"]), "No vantage for control121"): return
	if not check(owner.interaction_hint() == "E — Take the sword", "Hint: " + owner.interaction_hint()): return
	await process_frame
	if not check(hive.interface_hud.hint.text == "E — Take the sword", "HUD prompt: " + hive.interface_hud.hint.text): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/hive_reaver_view.png")
	await press_e()
	if not check(State.REAVER in hive.carried_inventory.collected and int(owner.state.reaver.state) == 2 and float(owner.state.reaver.timer) > State.REAVER_DELAY - 0.5, "Take Reaver: %s" % [owner.state.reaver]): return
	if not check(sword_parts.filter(func(p): return p.mesh.visible).all(func(p): return int(p.mask) & 2), "Empty-wall art"): return
	await press_e()
	if not check(hive.carried_inventory.collected.count(State.REAVER) == 1, "Reaver regranted"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/hive_reaver_taken.png")
	run_for(2.0)
	if not cycle("timer"): return
	if not check(owner.state.collapse.heights.is_empty() and float(owner.state.reaver.timer) > 5.0, "Collapse before timer"): return
	# Leave the corridor (region371), let the timer fire and the whole chain run.
	stand(center("371") + Vector3(0, 0, 0))
	run_for(6.0)
	if not check(not owner.state.collapse.heights.is_empty() and float(owner.state.reaver.timer) == 0.0, "Timer did not start the collapse: %s" % [owner.state]): return
	run_for(40.0)
	var want := {"364:floor":-185.0,"364:ceiling":-185.0,"365:floor":-234.0,"365:ceiling":-234.0,"366:ceiling":-235.0,"367:ceiling":-235.0,"368:ceiling":-235.0,"369:ceiling":-200.0,"370:ceiling":-185.0}
	for key in want:
		if not check(h(key) == want[key], "Final %s = %f" % [key, h(key)]): return
	if not check(owner.state.collapse.movers.is_empty() and owner.state.collapse.finished, "Collapse not finished: %s" % [owner.state.collapse]): return
	if not check(owner.slabs["367:ceiling"].body.visible and owner.slabs["367:ceiling"].shape.shape != null, "Slab367 missing"): return
	# The sealed corridor is solid: a point at head height inside region367 lies in its collapse slab.
	await physics_frame
	var space: PhysicsDirectSpaceState3D = hive.get_world_3d().direct_space_state
	var probe := PhysicsPointQueryParameters3D.new(); probe.position = center("367") + Vector3(0, 40, 0)
	var hits: Array = space.intersect_point(probe)
	if not check(hits.any(func(x): return str(x.collider.name) == "Collapse_367_ceiling"), "Corridor not sealed: %s" % [hits]): return
	if not check(not owner.target() == "121", "Sealed alcove still targetable"): return
	if not cycle("collapsed"): return
	# ---- Blocking: a player under region367 stops its ceiling and the chain waits ----
	var fresh := State.initial(); fresh.reaver = {"state":2,"timer":0.1}
	owner.restore(fresh)
	stand(center("367"))
	await physics_frame
	run_for(20.0)
	var head: float = owner._player_span().y
	if not check(h("367:ceiling") >= head and h("367:ceiling") < -107.0 and owner.state.collapse.movers.has("367:ceiling") and h("368:ceiling") == -107.0, "Blocking: 367=%f head=%f %s" % [h("367:ceiling"), head, owner.state.collapse]): return
	stand(center("371")); await physics_frame
	run_for(40.0)
	if not check(owner.state.collapse.finished and h("368:ceiling") == -235.0, "Chain did not resume"): return
	# ---- Amber ----
	if not check(await amber_view(), "No vantage for control123"): return
	if not check(owner.target() == "123", "No vantage for control123"): return
	if not check(owner.interaction_hint() == "E — Take amber", "Amber hint: " + owner.interaction_hint()): return
	for k in 3: await press_e()
	if not check(Items.pool().slice(0, 3).all(func(id): return id in hive.carried_inventory.collected) and int(owner.state.amber.state) == 5 and State.amber_selector(owner.state) == 3, "Three Amber: %s" % [owner.state.amber]): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/hive_amber_spent.png")
	var spent: Array = hive.carried_inventory.collected.duplicate()
	await press_e()
	if not check(hive.carried_inventory.collected == spent and owner.interaction_hint() == "The amber vein is spent.", "Spent vein harvested"): return
	if not cycle("amber_spent"): return
	run_for(State.AMBER_REGROW + 0.1)
	if not check(int(owner.state.amber.state) == 2 and State.amber_selector(owner.state) == 2, "Amber regrow: %s" % [owner.state.amber]): return
	if not await amber_view(): return
	await press_e()
	if not check(Items.pool()[3] in hive.carried_inventory.collected and int(owner.state.amber.state) == 5, "Amber after regrowth"): return
	# Capacity refusal is atomic.
	var full: Array = hive.carried_inventory.collected.duplicate()
	var Catalog = preload("res://scripts/lol2/item_catalog.gd")
	run_for(State.AMBER_REGROW + 0.1)
	var filler: Array = Catalog.ids("jungle").filter(func(id): return not id in full and not Items.valid(id))
	while hive.carried_inventory.collected.size() < Catalog.MAX_CARRIED: hive.carried_inventory.collected.append(filler.pop_back())
	if not check(await amber_view() and owner.interaction_hint() == "E — Take amber", "Capacity vantage"): return
	var snap: Dictionary = owner.checkpoint(); var capped: Array = hive.carried_inventory.collected.duplicate()
	await press_e()
	if not check(hive.carried_inventory.collected == capped and owner.checkpoint() == snap, "Harvest beyond MAX_CARRIED"): return
	hive.carried_inventory.collected = full
	# ---- Validation and identities ----
	var bad := State.initial(); bad.amber = {"state":5,"timer":0.0}
	if not check(not State.validate(bad).is_empty(), "Spent vein without timer accepted"): return
	bad = State.initial(); bad.collapse.heights["366:ceiling"] = -200.0
	if not check(not State.validate(bad).is_empty(), "Collapse without the Reaver accepted"): return
	bad = State.initial(); bad.reaver = {"state":1,"timer":0.0}
	if not check(not State.validate(bad).is_empty(), "Transient Reaver state1 accepted"): return
	var Names = preload("res://scripts/lol2/act_one_item_names.gd")
	if not check(Names.source_name(State.REAVER) == "18-Reaver of GO" and preload("res://scripts/lol2/player_equipment.gd").weapon(State.REAVER) and Catalog.admitted(State.REAVER, "jungle") and not Catalog.admitted(State.REAVER, "museum"), "Reaver identity"): return
	for id in Items.pool():
		if not check(Names.source_name(id) == "110-Amber" and Catalog.label(id) == "Amber" and Catalog.admitted(id, "jungle"), "Amber identity " + id): return
	if not check(owner.source.amber.item.identity == 2139463609, "Amber identity differs from Kityara's offer identity"): return
	# ---- Hive -> Jungle handoff ----
	var handoff: Dictionary = hive.area_handoff()
	if not check(handoff.quests.has("hive_reaver_amber"), "Handoff lacks hive_reaver_amber"): return
	hive.queue_free(); await process_frame; await process_frame
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in 3: await process_frame
	var error: String = jungle.apply_area_handoff(JSON.parse_string(JSON.stringify(handoff, "", true, true)))
	if not check(error.is_empty() and State.REAVER in jungle.carried_collected and Items.pool()[0] in jungle.carried_collected, "Jungle handoff: " + error): return
	print("PASS hive_reaver_amber_live: Reaver E take (wall art, one item), reload mid-timer, source collapse chain to final heights with collision, occupant blocks region367 and the chain resumes, Amber 3 harvests/spent/regrow/one more, capacity atomic, validation, identities, Hive->Jungle handoff.")
	quit()
