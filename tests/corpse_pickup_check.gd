extends RefCounted
## Extends the existing source-grant/real-death loot tests with early E and disk rollback.
static func run(test, cave, loot, actor: String, keys: Array, items: Array) -> bool:
	var pending := "user://tests/early_guard" + actor + "_pending.json"
	var taken := "user://tests/early_guard" + actor + "_taken.json"
	loot.present()
	if not test.check(float(loot.state.elapsed) == 0.0, "Early corpse clock starts at zero"): return false
	if not test.check(cave._quicksave(pending).is_empty(), "Save unlooted corpse"): return false
	for i in keys.size():
		var key: String = keys[i]
		var sprite: Node3D = loot.sprite if key.is_empty() else loot.sprites[key]
		if i == 0 and not test.check(not sprite.visible, "Early pickup precedes drop sprite"): return false
		var viewed := false
		for angle in range(90,450,15):
			var p: Vector3 = sprite.global_position
			cave.player.global_position = p + Vector3(sin(deg_to_rad(angle))*60,24,cos(deg_to_rad(angle))*60)
			cave.camera.look_at(p)
			await test.physics_frame
			var aimed = loot.aimed()
			if (key.is_empty() and aimed == true) or (not key.is_empty() and aimed == key):
				viewed = true
				break
		if not test.check(viewed, "Actual corpse reach/aim/occlusion guard" + actor + " " + key): return false
		var event := InputEventKey.new()
		event.keycode = KEY_E; event.pressed = true
		Input.parse_input_event(event); await test.process_frame
		event = InputEventKey.new(); event.keycode = KEY_E; event.pressed = false
		Input.parse_input_event(event); await test.process_frame
		if not test.check(cave.carried_items().count(items[i]) == 1 and float(loot.state.elapsed) == 5.0, "Early E grants one item and saves retirement"): return false
		if not test.check(cave._quicksave(taken).is_empty() and cave._quickload(taken).is_empty(), "Early pickup disk reload"): return false
		test.freeze(cave)
	if not test.check(not loot.collect(), "Collected corpse cannot duplicate items"): return false
	for item in items:
		if not test.check(cave.carried_items().count(item) == 1, "Early loot retained once"): return false
	if not test.check(cave._quickload(pending).is_empty(), "Restore pre-pickup save"): return false
	test.freeze(cave)
	for item in items:
		if not test.check(item not in cave.carried_items(), "Rollback removes early pickup"): return false
	return test.check(float(loot.state.elapsed) == 0.0, "Rollback restores pending timer")
