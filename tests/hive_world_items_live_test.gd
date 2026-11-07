extends SceneTree
## Hive original rows 5-9 in the live Hive host: placement, aim/overlay/duplicate/capacity guards, E pickup, hint,
## disk rollback, old-save default, consumed-item persistence and the Jungle carry. Approach points are a supplied
## fixture (searched next to each row); the earned walk to each row is not replayed here. Row 8 (Kelen's ring) lies in
## the 20-unit-high region 1224 with the hosted wax, so it is taken in the small form along the wax test's route.
const S = preload("res://scripts/lol2/hive_world_items_state.gd")
const C = preload("res://scripts/lol2/item_catalog.gd")
func _initialize() -> void: _run.call_deferred()
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func aim(scene: Node3D, point: Vector3) -> void:
	var direction: Vector3 = point-scene.camera.global_position
	scene.player.rotation.y = atan2(-direction.x,-direction.z)
	scene.camera.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
## A standing point near `row` from which the row is the admitted target.
func approach(scene: Node3D, items: Node3D, row: int) -> bool:
	var base: Vector3 = S.POSITIONS[S.ROWS.find(row)]
	for distance in [24.0, 36.0, 48.0, 64.0]:
		for step in 8:
			var angle := step*TAU/8.0
			scene.player.position = base + Vector3(cos(angle)*distance, 32, sin(angle)*distance)
			await physics_frame
			aim(scene, items.aim_point(row))
			await physics_frame
			if items.aimed_row() == row and not scene.wax.target(): return true
	return false
func walk(scene: Node3D, target: Vector3) -> void:
	for frame in range(240):
		var delta: Vector3 = target-scene.player.position
		delta.y = 0
		if delta.length() < 3.0: return
		scene.player.velocity = delta.normalized()*55.0 + Vector3(0,-15,0)
		scene.player.move_and_slide()
		await physics_frame
	assert(false,"Ring approach blocked: " + str(scene.player.position) + " -> " + str(target))
## Same supplied small-form approach as hive_wax_test (region 1224 is 20 units high).
func approach_ring(scene: Node3D, items: Node3D) -> bool:
	scene.player.position = Vector3(-3839.75,-919,-7015.25)
	var fixture: Dictionary = scene.area_handoff()
	fixture.inventory.player_form = 2
	fixture.inventory.erase("curse")
	assert(scene.apply_area_handoff(fixture).is_empty())
	scene.set_physics_process(false)
	for point in [Vector3(-3813.25,-919,-6990.5),Vector3(-3799,-919,-6974.75),Vector3(-3782.5,-919,-6957),Vector3(-3768,-919,-6948.25),Vector3(-3750,-919,-6945.5)]:
		await walk(scene,point)
	aim(scene, items.aim_point(8))
	await physics_frame
	return items.aimed_row() == 8 and not scene.wax.target()
func _run() -> void:
	var scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var items = scene.world_items
	assert(is_instance_valid(items) and items.sprites.size() == 5)
	for i in S.ROWS.size():
		assert(items.sprites[S.ROWS[i]].position == S.POSITIONS[i] and items.sprites[S.ROWS[i]].visible)
	var before: Dictionary = scene.area_handoff()
	assert(not before.quests.has(S.KEY))
	var path := "user://tests/hive_world_items_%d.json" % Time.get_ticks_usec()
	assert(scene.quicksave(path).is_empty())
	for i in [0, 1, 2, 4, 3]:
		var row: int = S.ROWS[i]
		if row == 8: assert(await approach_ring(scene, items), "Small-form fixture does not admit row 8")
		else: assert(await approach(scene, items, row), "No fixture point admits row %d" % row)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		assert(items.target() == row, "Row %d aimed but not admitted" % row)
		# The previous pickup's 3 s notice owns the hint line until it expires.
		scene.interface_hud.save_notice_remaining = 0.0
		scene.interface_hud._process(0.0)
		assert(scene.interface_hud.hint.text == "E — Take " + C.label(S.IDS[i]), scene.interface_hud.hint.text)
		scene.interface_hud.set_cursor(true)
		assert(not items.collect())
		scene.interface_hud.set_cursor(false)
		aim(scene, items.aim_point(row))
		if i == 0:
			# Capacity guard: a full pack refuses the pickup and leaves the row in place.
			var pack: Array = scene.carried_inventory.collected.duplicate()
			while scene.carried_inventory.collected.size() < C.MAX_CARRIED: scene.carried_inventory.collected.append("filler:%d" % scene.carried_inventory.collected.size())
			assert(items.collect() and items.sprites[row].visible and row not in items.collected)
			scene.carried_inventory.collected = pack
		key(KEY_E)
		assert(scene.interface_hud.hint.text == C.label(S.IDS[i]) + " taken.")
		assert(row in items.collected and not items.sprites[row].visible and S.IDS[i] in scene.carried_inventory.collected)
		assert(scene.carried_inventory.collected.count(S.IDS[i]) == 1)
		assert(items.target() != row and not items.collect())
	var collected: Dictionary = scene.area_handoff()
	assert(collected.quests[S.KEY] == {"version":1,"collected":[5,6,7,8,9]})
	assert(scene.quicksave(path+".after").is_empty())
	assert(scene.quickload(path).is_empty())
	for row in S.ROWS: assert(items.sprites[row].visible)
	for id in S.IDS: assert(id not in scene.carried_inventory.collected)
	assert(scene.quickload(path+".after").is_empty())
	for row in S.ROWS: assert(not items.sprites[row].visible)
	var bad: Dictionary = collected.duplicate(true)
	bad.quests[S.KEY] = {"version":1,"collected":[4]}
	assert(not scene.apply_area_handoff(bad).is_empty())
	# Items later spent or traded stay gone from the world.
	var with_items: Dictionary = collected.duplicate(true)
	var spent: Dictionary = collected.duplicate(true)
	for id in S.IDS: spent.inventory.collected.erase(id)
	assert(scene.apply_area_handoff(spent).is_empty())
	for row in S.ROWS: assert(not items.sprites[row].visible)
	# Jungle carry keeps both the items and the pickup history.
	var jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle)
	await process_frame
	await process_frame
	assert(jungle.apply_area_handoff(with_items).is_empty())
	var returned: Dictionary = jungle.area_handoff()
	for id in S.IDS: assert(id in returned.inventory.collected)
	assert(returned.quests[S.KEY] == {"version":1,"collected":[5,6,7,8,9]})
	assert(scene.apply_area_handoff(returned).is_empty())
	for row in S.ROWS: assert(not items.sprites[row].visible)
	jungle.free()
	# Older quest banks start with every row present.
	assert(scene.apply_area_handoff(before).is_empty())
	for row in S.ROWS: assert(items.sprites[row].visible)
	assert(not scene.area_handoff().quests.has(S.KEY))
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path+".after")
	scene.free()
	print("PASS: Hive rows5-9 pickups, aim/overlay/duplicate/capacity guards, hint, disk rollback, old-save default, spent-item persistence and Jungle carry")
	quit()
