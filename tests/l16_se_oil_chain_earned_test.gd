extends "res://tests/l12_logs_approach_earned_test.gd"
## STORY-071: earned L16 ground save -> south avenue -> canal bank -> SE oil.
## The west door pairs are kind 4: E runs the native group and opcode 1 opens the pair.
## Region 4947 rises 70 over a 48 run; since the terrace-lip adapter (ledger 0367) its collision is a 40-degree ramp, so the body walks down onto region 4946 (and the native link is walkable upward too).
## The human body walks under the region 5295 shelf (floor 90, head below it). The jump is
## from the floor-30 takeoff, before that overhang, onto region 5294.
const CANAL := [164, 165, 140, 141, 158, 159, 134, 135, 152, 153, 128, 129, 148, 149, 124, 125]
const LIP_LANDING := Vector2(-1273.0, 13725.0)

func key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame

func click() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	Input.parse_input_event(down)
	Input.flush_buffered_events()
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await process_frame

func stop(scene: Node, code: int) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	quit(code)

func travel_of(scene: Node, ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		out.append(int(scene.progression.travel.get(id, 0)))
	return out

func open_canal_door(scene: Node) -> bool:
	var origin: Vector3 = scene.player.position
	var best := -1
	var best_d := 130.0
	for id in CANAL:
		if int(scene.progression.travel.get(id, 0)) != 0:
			continue
		var point: Vector3 = scene.progression.movable_position(int(id))
		var flat: float = Vector2(point.x - origin.x, point.z - origin.z).length()
		if flat < best_d:
			best_d = flat
			best = int(id)
	if best < 0:
		return false
	var hinge: Vector3 = scene.progression.movable_position(best)
	# Dispatch the player's E before resuming controller movement. The direct
	# mover call in this physics-frame continuation produced a different body
	# displacement from ordinary E at the same stand (door149's swing arc).
	scene.camera.look_at(hinge + Vector3.UP * 32.0, Vector3.UP)
	await key(KEY_E)
	var opened: bool = int(scene.progression.travel.get(best, 0)) != 0
	print("CANAL door ", best, " opened ", opened, " travel ", int(scene.progression.travel.get(best, 0)))
	if opened:
		for wait_i in 40:
			scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
			await physics_frame
	return opened

func walk(scene: Node, points: Array, label: String) -> bool:
	var lip_jumped := false
	for index in points.size():
		var row: Array = points[index]
		var goal := Vector3(float(row[0]), 0.0, float(row[1]))
		var reached := false
		var prior: Vector3 = scene.player.position
		var stalled := 0
		for tick in 1600:
			if not await fight_nearby(scene):
				return false
			var d: Vector3 = goal - scene.player.position
			d.y = 0.0
			if d.length() < 7.0 and scene.player.is_on_floor():
				reached = true
				break
			if scene.player.position.distance_to(prior) < 0.05:
				stalled += 1
			else:
				stalled = 0
			prior = scene.player.position
			var goal_flat := Vector2(goal.x, goal.z)
			if not lip_jumped and scene.player.is_on_floor() and goal_flat.distance_to(LIP_LANDING) < 20.0 and scene.player.position.z > 13775.0:
				lip_jumped = true
				if not check(scene.request_jump(), "jump the oil stair before the shelf"):
					return false
				print("LIP jump ", scene.player.position)
			elif stalled == 20 and scene.player.is_on_floor():
				if await open_canal_door(scene):
					print("CANAL open ", index, " ", scene.player.position)
					stalled = 0
				else:
					if not check(scene.request_jump(), "actual jump at original stair lip"):
						return false
					print("STAIR jump ", index, " ", scene.player.position)
					stalled = 0
			scene.move_grounded(d.normalized(), 1.0 / 60.0)
			await physics_frame
			if tick % 300 == 0:
				print("OIL WALK ", label, " point", index, " ", scene.player.position, " region ", scene.progression.region_at(scene.player.position))
		if not check(reached, label + " point" + str(index) + " at " + str(scene.player.position)):
			return false
	return true

func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l16_ground_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned L16 ground save"):
		quit(1)
		return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)):
		quit(1)
		return
	var scene: Node = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	var loaded: bool = scene.ready_for_review and scene.apply_save(input.state).is_empty()
	if not check(loaded, "earned L16 ground input"):
		await stop(scene, 1)
		return
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var home: Vector2 = Vector2(scene.player.position.x, scene.player.position.z)
	if not check(home.distance_to(Vector2(-3797, 2291)) < 30.0, "ground landing"):
		await stop(scene, 1)
		return
	var avenue = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l16_ground_to_south_avenue.json"))
	if not check(avenue is Array and avenue.size() == 88, "avenue route"):
		await stop(scene, 1)
		return
	if not await walk(scene, avenue, "south avenue"):
		await stop(scene, 1)
		return
	print("AVENUE ", scene.player.position, " region ", scene.progression.region_at(scene.player.position))
	var canal = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l16_canal_to_oil.json"))
	if not check(canal is Array and canal.size() > 20, "canal route"):
		await stop(scene, 1)
		return
	if not await walk(scene, canal, "canal to the oil"):
		await stop(scene, 1)
		return
	var oil = scene.get_node("L16SeOil")
	print("OIL AT ", scene.player.position, " region ", scene.progression.region_at(scene.player.position), " resets ", scene.resets)
	if not check(scene.resets == 0, "no fall reset on the canal"):
		await stop(scene, 1)
		return
	scene.camera.look_at(oil.FOUNTAIN, Vector3.UP)
	await process_frame
	await process_frame
	if not check(oil.aimed(oil.FOUNTAIN, 180.0), "aimed at prop 392"):
		await stop(scene, 1)
		return
	await click()
	var doors: Array = travel_of(scene, oil.DOORS)
	var group_ran: bool = oil.fire_results.size() == 1 and str(oil.fire_results[0].get("status", "")) == "ran"
	if not check(group_ran and bool(oil.state().burned) and doors == [40, 100, 150], "group 14558 opens the fire doors"):
		print("BURN ", oil.fire_results, " ", doors)
		await stop(scene, 1)
		return
	if not await walk(scene, [[-2350.0, 12864.0], [-2500.0, 12858.0]], "to the Dark Bow"):
		await stop(scene, 1)
		return
	var items = scene.get_node("Act2WorldItems")
	scene.camera.look_at(items.aim_point(oil.BOW), Vector3.UP)
	await process_frame
	await process_frame
	await key(KEY_E)
	if not check(oil.BOW in scene.carried_collected and oil.BLUE in scene.carried_collected, "Dark Bow taken and the blue bow stays"):
		await stop(scene, 1)
		return
	var save := "res://tmp/l16_se_oil_chain_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "oil chain save"):
		await stop(scene, 1)
		return
	if not check(scene._quickload_unrecorded(save).is_empty(), "oil chain reload"):
		await stop(scene, 1)
		return
	oil = scene.get_node("L16SeOil")
	await process_frame
	var kept: bool = bool(oil.state().burned) and travel_of(scene, oil.DOORS) == [40, 100, 150] and oil.BOW in scene.carried_collected
	if not check(kept, "reload keeps the burn, the doors, and the Dark Bow"):
		await stop(scene, 1)
		return
	print("PASS earned L16 ground -> south avenue -> canal -> SE oil doors open -> Dark Bow taken")
	await stop(scene, 0)
