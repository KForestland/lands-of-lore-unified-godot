extends SceneTree
## Hive rune pit, as in the original (owner longplay 1:37:14-1:37:30): Spark (Q) or a fire crystal lights the brazier
## (no G key), and walking into the pit opens the RUNES room through the region506 tile groups; Escape returns to the
## tiles' own opcode18 pose. Supplied corridor/aim fixtures; the earned route is hive_earned_rune_walk_test.
const Pit = preload("res://scripts/lol2/hive_rune_entry.gd")
const CRYSTAL := "museum:item4:Fire_Crystal"
var scene
func _initialize(): run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		quit(1)
	return ok
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func aim(point: Vector3) -> void:
	var direction: Vector3 = point-scene.camera.global_position
	scene.player.rotation.y = atan2(-direction.x,-direction.z)
	scene.camera.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
func stand(xz: Vector2) -> void:
	scene.player.velocity = Vector3.ZERO
	scene.player.position = Vector3(xz.x,-1659+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET+scene.player.safe_margin,xz.y)
func run():
	scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(false)
	root.grab_focus()
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var entry = scene.runes
	var light = scene.rune_light
	var hosted: Array = entry.pit.tiles.filter(func(t): return int(t.room_index) == 11)
	if not check(entry.pit.tiles.size() == 105 and hosted.size() == 104,"Pit source tiles differ"): return
	# Brazier: G is no longer a light key.
	stand(Vector2(-3113,-6282))
	await physics_frame
	aim(light.aim_point())
	await physics_frame
	scene.player_magic_checkpoint = {"version":1,"player":{"experience":0,"level":1,"maximum":20,"mana":20}}
	if not check(light.target(),"Brazier not aimable from the corridor"): return
	scene.interface_hud._process(0)
	if not check(scene.interface_hud.hint.text == "Q — Cast Spark","Spark hint must name Q"): return
	key(KEY_G)
	if not check(not entry.checkpoint.lights and scene.player_magic_checkpoint.player.mana == 20,"G lit the brazier"): return
	var unlit := "user://tests/rune_pit_unlit_%d.json" % Time.get_ticks_usec()
	if not check(scene.quicksave(unlit).is_empty(),"Unlit save failed"): return
	# Fire crystal from the inventory: lights the brazier for one charge, no mana.
	scene.carried_inventory.collected.append(CRYSTAL)
	var effects: Dictionary = scene.item_effects.state()
	if not effects.has("fire_crystals"): effects.fire_crystals = {}
	effects.fire_crystals[CRYSTAL] = 2
	if not check(scene.open_inventory(),"Inventory did not open"): return
	await process_frame
	if not check(scene.use_inventory_item(CRYSTAL),"Fire crystal use refused"): return
	if not check(entry.checkpoint.lights and light.glow.visible and scene.player_magic_checkpoint.player.mana == 20 and scene.item_effects.crystal_charges(CRYSTAL) == 1,"Fire crystal did not light the brazier for one charge"): return
	if is_instance_valid(scene.inventory): scene.inventory.queue_free()
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Spark (Q) lights it too, for 1 mana.
	if not check(scene.quickload(unlit).is_empty() and not entry.checkpoint.lights,"Unlit rollback failed"): return
	scene.set_physics_process(false)
	stand(Vector2(-3113,-6282))
	await physics_frame
	aim(light.aim_point())
	await physics_frame
	scene.starting_magic.select_spell("spark")
	key(KEY_Q)
	if not check(entry.checkpoint.lights and scene.player_magic_checkpoint.player.mana == 19,"Spark did not light the brazier"): return
	# Walk from the corridor into the pit: no E; the tile group opens RUNES.
	if not check(not entry.checkpoint.marker642_enabled and not entry.active(),"Fixture already entered"): return
	stand(Vector2(-3113,-6282))
	scene.player.rotation.y = 0
	scene.camera.rotation.x = 0
	var target := Vector2(-3190,-6230)
	var entered_from := Vector3.ZERO
	for frame in range(600):
		await physics_frame
		if entry.active(): break
		entered_from = scene.player.position
		var offset: Vector2 = target-Vector2(scene.player.position.x,scene.player.position.z)
		var direction := offset.normalized() if offset.length() > 2.0 else Vector2.ZERO
		scene.move_grounded(Vector3(direction.x,0,direction.y),scene.player.get_physics_process_delta_time())
	if not check(entry.active() and entry.checkpoint.room == "RUNES","Walking into the pit did not open the rune room (at %s)" % [scene.player.position]): return
	var tile: Dictionary = entry.pit_tile_at(entered_from)
	if not check(not tile.is_empty() and entered_from.y < -1659+30.0,"Room opened before the player stood in the pit: %s" % [entered_from]): return
	print("Pit entered on region ",tile.region," at ",entered_from," marker642=",entry.checkpoint.marker642_enabled)
	if not check(entry.checkpoint.marker642_enabled == bool(tile.marker642) and Vector2(entry.checkpoint.return_xz[0],entry.checkpoint.return_xz[1]) == Vector2(-3113,-6282),"Tile group effects differ"): return
	if not check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and entry.activate_hotspot(2),"Lit room did not admit the inscription"): return
	var inside := "user://tests/rune_pit_room_%d.json" % Time.get_ticks_usec()
	if not await preload("res://tests/rune_speech_wait.gd").settle(self,entry): return
	if not check(scene.quicksave(inside).is_empty() and scene.quickload(inside).is_empty() and entry.active() and Vector2(entry.checkpoint.return_xz[0],entry.checkpoint.return_xz[1]) == Vector2(-3113,-6282),"Pit room save lost its return"): return
	var bad: Dictionary = scene.area_handoff()
	bad.quests.hive_rune_entry.return_xz = [0,0]
	if not check(not scene.apply_area_handoff(bad).is_empty(),"Invalid pit return accepted"): return
	entry.leave()
	if entry.active(): entry.leave()
	if not check(not entry.active() and not entry.checkpoint.has("return_xz"),"Escape did not close the room"): return
	if not check(Vector2(scene.player.position.x,scene.player.position.z) == Vector2(-3113,-6282) and scene.player.position.y >= -1659+31.0,"Pit return pose differs: %s" % [scene.player.position]): return
	if not check(is_equal_approx(scene.player.rotation.y,-PI/4),"Pit return bearing differs"): return
	scene.set_physics_process(false)
	for frame in range(30):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	if not check(not entry.active() and scene.player.is_on_floor(),"Return did not settle on the corridor floor"): return
	scene.queue_free()
	await process_frame
	await process_frame
	print("PASS: rune pit — no G key, fire crystal and Spark light the brazier, walking into the pit opens RUNES, tile return pose and saves")
	quit()
