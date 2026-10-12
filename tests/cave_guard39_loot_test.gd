extends "res://tests/player_magic_handoff_test.gd"
## Guard39: prop1235 arrival grant (ADF34, no predicate); supplied region631 spawn contact and camera vantage,
## then real damage/input/save/transfer. Guard38 must stay unaffected.
const Generic = preload("res://scripts/lol2/scripted_creature_state.gd")
const Loot = preload("res://scripts/lol2/cave_guard39_loot.gd")
func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func run() -> void:
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene = cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready: break
	if not check(cave.walkthrough_ready,"Cave ready"): return
	freeze(cave); cave.flying = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var g = cave.guard_population
	var loot = cave.guard39_loot
	if not check(loot.checkpoint() == null and not loot.sprite.visible,"Legacy initial state unchanged"): return
	var region: Dictionary = {}
	for row in g.src.regions:
		if int(row.region) == 631: region = row
	var centre := Vector2.ZERO
	for p in region.polygon: centre += Vector2(p[0],p[1])
	centre /= region.polygon.size()
	Generic.contact(g.state,g.src,Vector3(centre.x,region.floor_min,centre.y),float(region.floor_min),0)
	if not check(g.restore(g.checkpoint()).is_empty() and g.state.actors["39"].present,"Source region631 spawn"): return
	if not check(g.receive_damage("39",1000,true),"Production lethal damage"): return
	loot.advance(2)
	if not check(not loot.sprite.visible and Loot.ITEM not in cave.carried_items(),"Drop before retirement"): return
	var path := "user://tests/guard39_loot.json"
	var pending_path := "user://tests/guard39_loot_pending.json"
	var error: String = cave._quicksave(pending_path)
	if not check(error.is_empty(),"Pending guard loot save: " + error): return
	var death_position: Vector3 = g.bodies["39"].global_position + Vector3.UP * 8
	error = cave._quicksave(path)
	if not check(error.is_empty(),"Partial guard loot save: " + error): return
	paused = true; loot.advance(10); paused = false
	if not check(loot.state.elapsed == 2,"Pause advanced drop"): return
	loot.advance(3)
	if not check(loot.sprite.visible and not g.bodies["39"].visible,"Retirement presents drop"): return
	error = cave._quickload(path)
	if not check(error.is_empty() and loot.state.elapsed == 2 and not loot.sprite.visible,"Partial reload: " + error): return
	freeze(cave); loot.advance(3)
	var viewed := false
	for angle in range(90,450,15):
		var p: Vector3 = loot.sprite.global_position
		cave.player.global_position = p + Vector3(sin(deg_to_rad(angle))*60,24,cos(deg_to_rad(angle))*60)
		cave.camera.look_at(p); await physics_frame
		if loot.aimed(): viewed = true; break
	if not check(viewed,"Actual reach/aim/occlusion sees guard drop"): return
	cave._process(0) # Synchronize indexed render cameras after supplied fixture movement.
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/guard39_visible_drop.png")
	var event := InputEventKey.new(); event.keycode = KEY_E; event.pressed = true
	Input.parse_input_event(event); await process_frame
	event = InputEventKey.new(); event.keycode = KEY_E; event.pressed = false
	Input.parse_input_event(event); await process_frame
	if not check(loot.state.taken and cave.carried_items().count(Loot.ITEM) == 1,"Dispatched E pickup"): return
	if not check(cave.set_equipped_item(Loot.ITEM),"Guard sword equips"): return
	if not check(cave._quicksave(path).is_empty() and cave._quickload(path).is_empty(),"Equipped drop disk save/reload"): return
	freeze(cave); loot.advance(20)
	if not check(cave.equipped_item == Loot.ITEM and cave.carried_items().count(Loot.ITEM) == 1 and not loot.sprite.visible,"Reload duplicated/lost sword"): return
	# Production control109 group10114 hides actor39 after looting: hide39 retains the dead actor, resets population39.
	var controls = cave.guard_controls
	controls.apply(controls.State.plate(controls.state, controls.src, 109, 9))
	if not check(not controls.state.hidden39.is_empty() and int(controls.state.hidden39.actor.health) == 0 and not (g.state.actors["39"].present and int(g.state.actors["39"].health) == 0), "control109 did not retain/reset actor39: %s" % [controls.state.hidden39]): return
	if not check(Loot.validate(loot.checkpoint(),g.checkpoint(),controls.checkpoint()).is_empty(),"Taken receipt rejected after control109"): return
	if not check(cave._quicksave(path).is_empty() and cave._quickload(path).is_empty(),"Taken->control109 disk save/reload"): return
	freeze(cave); loot.advance(5)
	if not check(loot.state.taken and cave.carried_items().count(Loot.ITEM) == 1 and cave.equipped_item == Loot.ITEM and not loot.sprite.visible,"Taken->control109 reload lost/duplicated sword"): return
	var living_hidden: Dictionary = controls.checkpoint(); living_hidden.hidden39.actor.health = 1
	var reset_guards: Dictionary = g.checkpoint()
	if not check(not Loot.validate(loot.checkpoint(),reset_guards,living_hidden).is_empty(),"Living retained guard39 admitted"): return
	# Pending drop -> control109 removal -> retirement/pickup at the death position.
	if not check(cave._quickload(pending_path).is_empty() and float(loot.state.elapsed) == 2 and not loot.state.taken,"Reload pending drop"): return
	freeze(cave)
	controls.apply(controls.State.plate(controls.state, controls.src, 109, 9))
	if not check(not controls.state.hidden39.is_empty() and Loot.validate(loot.checkpoint(),g.checkpoint(),controls.checkpoint()).is_empty(),"Pending receipt rejected after control109"): return
	loot.advance(3)
	if not check(loot.sprite.visible and loot.sprite.global_position.distance_to(death_position) < 2.0,"Hidden-corpse drop missing or moved: %s vs %s" % [loot.sprite.global_position, death_position]): return
	viewed = false
	for angle in range(90,450,15):
		var p: Vector3 = loot.sprite.global_position
		cave.player.global_position = p + Vector3(sin(deg_to_rad(angle))*60,24,cos(deg_to_rad(angle))*60)
		cave.camera.look_at(p); await physics_frame
		if loot.aimed(): viewed = true; break
	if not check(viewed,"Hidden-corpse drop not aimable"): return
	event = InputEventKey.new(); event.keycode = KEY_E; event.pressed = true
	Input.parse_input_event(event); await process_frame
	event = InputEventKey.new(); event.keycode = KEY_E; event.pressed = false
	Input.parse_input_event(event); await process_frame
	if not check(loot.state.taken and cave.carried_items().count(Loot.ITEM) == 1 and cave.set_equipped_item(Loot.ITEM),"Pickup after control109"): return
	if not check(cave._quicksave(path).is_empty() and cave._quickload(path).is_empty(),"Pending->control109->pickup disk save/reload"): return
	freeze(cave)
	if not check(cave.carried_items().count(Loot.ITEM) == 1 and cave.equipped_item == Loot.ITEM,"Reload after control109 pickup"): return
	var removed: Dictionary = g.checkpoint(); removed.actors["39"].present = false
	removed.actors["39"].health = 0
	if not check(not Loot.validate(loot.checkpoint(),removed,{"hidden39":{}}).is_empty(),"Drop from a non-retained removed guard admitted"): return
	if not check(cave.guard38_loot.checkpoint() == null and not cave.guard38_loot.sprite.visible and cave.carried_items().count("cave:guard38:Short_Sword") == 0,"Guard38 loot affected"): return
	var living: Dictionary = g.checkpoint(); living.actors["39"].health = 1; living.actors["39"].present = true
	if not check(not Loot.validate(loot.checkpoint(),living,{"hidden39":{}}).is_empty(),"Living guard loot admitted"): return
	var bad: Dictionary = loot.checkpoint(); bad.elapsed = NAN
	if not check(not Loot.validate(bad,g.state).is_empty(),"NaN clock admitted"): return
	set_meta("lol2_cave_completion",cave._completion_state())
	await finish(cave)
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(museum); current_scene = museum; await process_frame
	freeze(museum); museum.introduction_state = "complete"
	if is_instance_valid(museum.introduction): museum.introduction.close(); await process_frame
	if not check(museum.carried_collected.count(Loot.ITEM) == 1 and museum.equipped_item == Loot.ITEM and museum.quicksave(path).is_empty(),"Museum transport/save lost guard loot"): return
	await finish(museum)
	print("PASS guard39 prop1235 arrival grant (region631 spawn), real death, retirement/pause/partial disk, dispatched E pickup, equip/no duplicate, production control109 hide after taken (disk) and while pending (retire/pickup at death position), Museum transport; supplied contact/camera scope")
	quit()
