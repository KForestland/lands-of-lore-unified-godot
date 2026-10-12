extends "res://tests/player_magic_handoff_test.gd"
## Guard54: two arrival grants (prop1013 property4, actor54 property1); supplied region969 spawn contact and camera
## vantage, then real damage, two individual dispatched E pickups, disk save/reload between them, equip, Museum transfer.
const Generic = preload("res://scripts/lol2/scripted_creature_state.gd")
const Loot = preload("res://scripts/lol2/cave_guard54_loot.gd")
var cave
var loot
func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func press_e() -> void:
	var event := InputEventKey.new(); event.keycode = KEY_E; event.pressed = true
	Input.parse_input_event(event); await process_frame
	event = InputEventKey.new(); event.keycode = KEY_E; event.pressed = false
	Input.parse_input_event(event); await process_frame
func aim_at(key: String) -> bool:
	for angle in range(90,450,15):
		var p: Vector3 = loot.sprites[key].global_position
		cave.player.global_position = p + Vector3(sin(deg_to_rad(angle))*60,24,cos(deg_to_rad(angle))*60)
		cave.camera.look_at(p); await physics_frame
		if loot.aimed() == key: return true
	return false
func run() -> void:
	cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene = cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready: break
	if not check(cave.walkthrough_ready,"Cave ready"): return
	freeze(cave); cave.flying = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var g = cave.guard_population
	loot = cave.guard54_loot
	if not check(loot.checkpoint() == null and not loot.sprites.prop1013.visible and not loot.sprites.actor54.visible,"Initial state"): return
	var region: Dictionary = {}
	for row in g.src.regions:
		if int(row.region) == 969: region = row
	var centre := Vector2.ZERO
	for p in region.polygon: centre += Vector2(p[0],p[1])
	centre /= region.polygon.size()
	Generic.contact(g.state,g.src,Vector3(centre.x,region.floor_min,centre.y),float(region.floor_min),0)
	if not check(g.restore(g.checkpoint()).is_empty() and g.state.actors["54"].present,"Source region969 spawn"): return
	if not check(g.receive_damage("54",1000,true),"Production lethal damage"): return
	# Exercise engine scheduling: no direct advance/present call can satisfy this check.
	loot.set_physics_process(true); loot.set_process(true)
	for i in 8: await physics_frame
	if not check(float(loot.state.elapsed) > 0.0,"Live engine did not advance retirement"): return
	loot.state.elapsed = Loot.DELAY - 0.05
	for i in 8: await physics_frame
	await process_frame
	if not check(loot.sprites.prop1013.visible and loot.sprites.actor54.visible and not g.bodies["54"].visible,"Live engine did not present retired loot"): return
	loot.set_physics_process(false); loot.set_process(false)
	loot.restore(null)
	loot.advance(2)
	if not check(not loot.sprites.prop1013.visible and Loot.ITEMS.prop1013 not in cave.carried_items(),"Drop before retirement"): return
	var path := "user://tests/guard54_loot.json"
	if not check(cave._quicksave(path).is_empty(),"Partial save"): return
	paused = true; loot.advance(10); paused = false
	if not check(loot.state.elapsed == 2,"Pause advanced drop"): return
	loot.advance(3)
	if not check(loot.sprites.prop1013.visible and loot.sprites.actor54.visible and not g.bodies["54"].visible,"Retirement presents both drops"): return
	if not check(loot.sprites.prop1013.global_position.distance_to(loot.sprites.actor54.global_position) > 10,"Drops overlap"): return
	if not check(cave._quickload(path).is_empty() and loot.state.elapsed == 2 and not loot.sprites.actor54.visible,"Partial reload"): return
	freeze(cave); loot.advance(3)
	# First pickup: the prop1013 sword only.
	if not check(await aim_at("prop1013"),"Aim prop1013 drop"): return
	cave._process(0)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/guard54_visible_drops.png")
	await press_e()
	if not check(loot.state.taken.prop1013 and not loot.state.taken.actor54 and cave.carried_items().count(Loot.ITEMS.prop1013) == 1 and cave.carried_items().count(Loot.ITEMS.actor54) == 0 and loot.sprites.actor54.visible,"Individual first pickup"): return
	if not check(Loot.validate(loot.checkpoint(),g.checkpoint()).is_empty() and cave._quicksave(path).is_empty() and cave._quickload(path).is_empty(),"One-taken disk save/reload"): return
	freeze(cave)
	if not check(loot.state.taken.prop1013 and not loot.state.taken.actor54 and loot.sprites.actor54.visible and not loot.sprites.prop1013.visible,"One-taken reload"): return
	# Second pickup: the actor54 sword.
	if not check(await aim_at("actor54"),"Aim actor54 drop"): return
	await press_e()
	if not check(loot.state.taken.actor54 and cave.carried_items().count(Loot.ITEMS.actor54) == 1 and cave.carried_items().count(Loot.ITEMS.prop1013) == 1,"Second pickup"): return
	if not check(cave.set_equipped_item(Loot.ITEMS.actor54),"Guard54 sword equips"): return
	if not check(cave._quicksave(path).is_empty() and cave._quickload(path).is_empty(),"Both-taken equipped disk save/reload"): return
	freeze(cave); loot.advance(20)
	if not check(cave.equipped_item == Loot.ITEMS.actor54 and cave.carried_items().count(Loot.ITEMS.prop1013) == 1 and cave.carried_items().count(Loot.ITEMS.actor54) == 1 and not loot.sprites.prop1013.visible and not loot.sprites.actor54.visible,"Reload duplicated/lost swords"): return
	# Rejections.
	var living: Dictionary = g.checkpoint(); living.actors["54"].health = 1
	if not check(not Loot.validate(loot.checkpoint(),living).is_empty(),"Living guard54 loot admitted"): return
	var absent: Dictionary = g.checkpoint(); absent.actors["54"].present = false
	if not check(not Loot.validate(loot.checkpoint(),absent).is_empty(),"Absent guard54 loot admitted"): return
	var early: Dictionary = loot.checkpoint(); early.elapsed = 1.0
	if not check(not Loot.validate(early,g.checkpoint()).is_empty(),"Taken before retirement admitted"): return
	var merged: Dictionary = loot.checkpoint(); merged.taken.erase("actor54")
	if not check(not Loot.validate(merged,g.checkpoint()).is_empty(),"Collapsed receipt admitted"): return
	if not check(cave.guard38_loot.checkpoint() == null and cave.carried_items().count("cave:guard38:Short_Sword") == 0,"Guard38 loot affected"): return
	set_meta("lol2_cave_completion",cave._completion_state())
	await finish(cave)
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(museum); current_scene = museum; await process_frame
	freeze(museum); museum.introduction_state = "complete"
	if is_instance_valid(museum.introduction): museum.introduction.close(); await process_frame
	if not check(museum.carried_collected.count(Loot.ITEMS.prop1013) == 1 and museum.carried_collected.count(Loot.ITEMS.actor54) == 1 and museum.equipped_item == Loot.ITEMS.actor54 and museum.quicksave(path).is_empty(),"Museum transport/save lost guard54 loot"): return
	await finish(museum)
	print("PASS guard54 two arrival grants (prop1013 property4 + actor54 property1, region969 spawn), real death, retirement/pause/partial disk, two individual dispatched E pickups with disk reload between, equip/no duplicate, collapsed-receipt rejection, Museum transport of both; supplied contact/camera scope")
	quit()
