extends "res://tests/player_magic_handoff_test.gd"
## Supplied fighting checkpoint; actual damage, world pickup, disk and transfer paths.
const CaptainState = preload("res://scripts/lol2/cave_captain_state.gd")
const Items = preload("res://scripts/lol2/cave_captain_items.gd")
func freeze(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child in node.get_children(): freeze(child)
func run() -> void:
	var cave = load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(cave); current_scene = cave
	for i in 600:
		await process_frame
		if cave.walkthrough_ready: break
	if not check(cave.walkthrough_ready, "Cave ready"): return
	freeze(cave); cave.flying = false; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var captain = cave.captain
	captain.set_physics_process(false)
	var packet: Dictionary = captain.initial()
	CaptainState.plate_entered(packet.source, captain.src, 89, 4)
	CaptainState.control_animation_finished(packet.source, captain.src)
	packet.movie_done = true
	if not check(captain.restore(packet).is_empty(), "Supplied fighting checkpoint"): return
	if not check(cave.guard_population.receive_damage("56", 1000, true), "Actual lethal damage"): return
	if not check(captain.state.source.captain.items == ["5-Short swd"] and captain.state.source.granted.is_empty(), "Source fighting death grants only actor sword"): return
	captain.advance(2)
	if not check(not captain.loot.sprite.visible and Items.SWORD not in cave.carried_items(), "No premature loot"): return
	var path := "user://tests/captain_loot.json"
	if not check(cave._quicksave(path).is_empty(), "Partial delay save"): return
	paused = true; captain.advance(10); paused = false
	if not check(captain.state.loot.elapsed == 2, "Pause freezes retirement adapter"): return
	captain.advance(3)
	if not check(captain.loot.sprite.visible, "Sword becomes visible"): return
	if not check(cave._quickload(path).is_empty() and captain.state.loot.elapsed == 2 and not captain.loot.sprite.visible, "Partial delay restored"): return
	freeze(cave); captain.set_physics_process(false); captain.advance(3)
	var viewed := false
	for angle in range(0, 360, 15):
		var p: Vector3 = captain.loot.sprite.global_position
		cave.player.global_position = p + Vector3(sin(deg_to_rad(angle))*60, 24, cos(deg_to_rad(angle))*60)
		cave.camera.look_at(p); await physics_frame
		if captain.loot.aimed(): viewed = true; break
	if not check(viewed, "Real reach/aim/occlusion sees drop"): return
	cave._process(0) # Synchronize the indexed render cameras after supplied camera movement.
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tmp/captain_combat_loot.png")
	var event := InputEventKey.new(); event.keycode = KEY_E; event.pressed = true
	cave._unhandled_input(event)
	if not check(captain.state.loot.taken and cave.carried_items().count(Items.SWORD) == 1 and not captain.loot.sprite.visible, "Host E collects exactly one sword"): return
	cave._unhandled_input(event)
	if not check(cave.carried_items().count(Items.SWORD) == 1 and cave.set_equipped_item(Items.SWORD), "No duplication; sword equips"): return
	if not check(cave._quicksave(path).is_empty() and cave._quickload(path).is_empty(), "Equipped loot disk reload"): return
	freeze(cave); captain.set_physics_process(false); captain.advance(20)
	if not check(cave.equipped_item == Items.SWORD and not captain.loot.sprite.visible and cave.carried_items().count(Items.SWORD) == 1, "Reload does not respawn loot"): return
	var bad: Dictionary = captain.checkpoint(); bad.loot.elapsed = NAN
	if not check(not captain.validate(bad).is_empty(), "Malformed clock rejected"): return
	bad = captain.checkpoint(); bad.source.captain.items = []
	if not check(not captain.validate(bad).is_empty(), "Missing source grant rejected"): return
	var transfer: Dictionary = cave._completion_state()
	set_meta("lol2_cave_completion", transfer)
	await finish(cave)
	var museum = load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	root.add_child(museum); current_scene = museum
	await process_frame; freeze(museum)
	if not check(museum.carried_collected.count(Items.SWORD) == 1 and museum.equipped_item == Items.SWORD, "Actual Museum arrival retains combat loot"): return
	museum.introduction_state = "complete"
	if is_instance_valid(museum.introduction): museum.introduction.close(); await process_frame
	var save_error: String = museum.quicksave(path)
	if not check(save_error.is_empty(), "Museum loot save validates: " + save_error): return
	await finish(museum)
	print("PASS captain fighting-death sword: delay/pause, host E, equipped disk reload/no duplication, actual Museum transfer; supplied fighting checkpoint and camera vantage")
	quit()
