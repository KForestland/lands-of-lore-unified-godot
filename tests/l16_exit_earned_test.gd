extends "res://tests/l12_logs_approach_earned_test.gd"
## STORY-077 and STORY-078 from the earned oil-chain save.
## Reverse the canal onto the main floor, stand on control 80, pose into the centre,
## stand in region 218, leave on control 79, chop prop 241, and walk onto control 74.
const Pads = preload("res://scripts/lol2/l16_centre_pads.gd")
const BARS := Vector3(5511, 32, 9888)

## Actor 46 (HL3) has 2000 hp and stays about 60 away, so the shared 6000-tick
## budget ends while it is still up. The longer budget is only this walk.
func combat_tick_budget() -> int:
	return 12000

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

func open_nearby_door(scene: Node) -> bool:
	var origin: Vector3 = scene.player.position
	var best := -1
	var best_d := 110.0
	var ids: Array[int] = scene.progression.scripted_movables
	for id in ids:
		if int(scene.progression.travel.get(id, 0)) != 0:
			continue
		var point: Vector3 = scene.progression.movable_position(id)
		if point == Vector3.INF:
			continue
		var flat := Vector2(point.x - origin.x, point.z - origin.z).length()
		if flat < best_d:
			best_d = flat
			best = id
	# Group 49836 on the west leaf stores 1 at prop 128. The east leaf slides
	# the same pair and leaves that byte unknown, so the walk uses the west leaf
	# when both are in reach.
	if best == 85:
		var west: Vector3 = scene.progression.movable_position(84)
		if west != Vector3.INF and int(scene.progression.travel.get(84, 0)) == 0:
			var west_d: float = Vector2(west.x - origin.x, west.z - origin.z).length()
			if west_d < 110.0:
				best = 84
	if best < 0:
		return false
	var hinge: Vector3 = scene.progression.movable_position(best)
	scene.camera.look_at(hinge, Vector3.UP)
	var results: Array = scene.progression.use(best)
	var opened := false
	for row in results:
		if str(row.get("status", "")) == "ran":
			opened = true
	if opened:
		print("DOOR ", best, " ", scene.player.position)
		for _wait in 30:
			scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
			await physics_frame
	return opened

func walk(scene: Node, points: Array, label: String, use_arrive: bool = false, arrive: Vector3 = Vector3.ZERO) -> bool:
	var jumped: Dictionary = {}
	for index in points.size():
		var row: Array = points[index]
		var goal := Vector3(float(row[0]), 0.0, float(row[1]))
		var reached := false
		var prior: Vector3 = scene.player.position
		var stalled := 0
		for tick in 1600:
			if not await fight_nearby(scene):
				return false
			if use_arrive and scene.player.position.distance_to(arrive) < 12.0:
				print("ARRIVE ", label, " ", scene.player.position)
				return true
			var d: Vector3 = goal - scene.player.position
			d.y = 0.0
			if d.length() < 7.0 and scene.player.is_on_floor():
				reached = true
				break
			if row.size() >= 3 and int(row[2]) == 1 and not jumped.has(index) and d.length() < 22.0 and scene.player.is_on_floor():
				jumped[index] = true
				if not check(scene.request_jump(), "jump the floor step"):
					return false
				print("STEP jump ", label, " ", index, " ", scene.player.position)
			if scene.player.position.distance_to(prior) < 0.05:
				stalled += 1
			else:
				stalled = 0
			prior = scene.player.position
			if stalled == 24 and scene.player.is_on_floor():
				if await open_nearby_door(scene):
					stalled = 0
				else:
					if not check(scene.request_jump(), "jump when the body stops"):
						return false
					print("STALL jump ", label, " ", index, " ", scene.player.position)
					stalled = 0
			scene.move_grounded(d.normalized(), 1.0 / 60.0)
			await physics_frame
			if tick % 400 == 0:
				print("EXIT WALK ", label, " point", index, " ", scene.player.position, " region ", scene.progression.region_at(scene.player.position))
		if not check(reached, label + " point" + str(index) + " at " + str(scene.player.position)):
			return false
	return scene.resets == 0

func route(path: String) -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		return parsed
	return []

func mantle_posed(scene: Node, id: int) -> bool:
	var row: Variant = scene.prop_placements.get(id)
	if not row is Array:
		return false
	var entry: Array = row
	var at: Vector3 = entry[2]
	var multi: MultiMesh = entry[0]
	var origin: Vector3 = multi.get_instance_transform(int(entry[1])).origin
	var dest: Vector3 = preload("res://scripts/lol2/l16_centre_tower.gd").pose_for(id)
	return absf(origin.x - dest.x) < 1.0 and absf(origin.z - dest.z) < 1.0 and origin.y > at.y + 20.0

func run() -> void:
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l16_se_oil_chain_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned oil chain save"):
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
	if not check(loaded, "earned oil chain input"):
		await stop(scene, 1)
		return
	prepare(scene)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var home := Vector2(scene.player.position.x, scene.player.position.z)
	var oil_state: Variant = scene.quest_state.get("l16_se_oil", {})
	var oil_ok: bool = oil_state is Dictionary and bool(oil_state.get("burned", false))
	oil_ok = oil_ok and home.distance_to(Vector2(-2494, 12858)) < 40.0
	if not check(oil_ok, "oil chain save stands at the bow with the burn"):
		await stop(scene, 1)
		return
	var canal: Array = route("res://tests/fixtures/l16_canal_to_oil.json")
	if not check(canal.size() == 154, "canal route"):
		await stop(scene, 1)
		return
	var back: Array = []
	for index in range(canal.size() - 1, 104, -1):
		back.append(canal[index])
	if not await walk(scene, back, "back along the canal"):
		await stop(scene, 1)
		return
	print("MAIN ", scene.player.position, " region ", scene.progression.region_at(scene.player.position), " resets ", scene.resets)
	if not await walk(scene, route("res://tests/fixtures/l16_exit_to_pad.json"), "to control 80", true, Pads.IN_POSE):
		await stop(scene, 1)
		return
	await process_frame
	await process_frame
	if not check(scene.player.position.distance_to(Pads.IN_POSE) < 8.0, "control 80 poses the centre landing: %s" % scene.player.position):
		await stop(scene, 1)
		return
	if not await walk(scene, route("res://tests/fixtures/l16_exit_centre_bars.json"), "to the mantle bars"):
		await stop(scene, 1)
		return
	await process_frame
	await process_frame
	await process_frame
	var hall = scene.get_node("L16CentreTower")
	var locals: Variant = scene.progression.native.get("locals")
	var local12 := -1
	if locals is Dictionary:
		local12 = int(locals.get(12, -1))
	var posed: bool = bool(hall.state().conveyed) and mantle_posed(scene, 331) and local12 == 1
	posed = posed and scene.player.position.distance_to(BARS) < 8.0 and not hall.relocates_player() and hall.DOOR_ID == -1
	if not check(posed, "region 218 poses the mantle props and Luther stays at %s" % scene.player.position):
		await stop(scene, 1)
		return
	if not await walk(scene, route("res://tests/fixtures/l16_exit_centre_out.json"), "to control 79", true, Pads.OUT_POSE):
		await stop(scene, 1)
		return
	await process_frame
	await process_frame
	if not check(scene.player.position.distance_to(Pads.OUT_POSE) < 8.0, "control 79 poses the city landing: %s" % scene.player.position):
		await stop(scene, 1)
		return
	if not await walk(scene, route("res://tests/fixtures/l16_exit_to_dragon.json"), "toward the dragon room"):
		await stop(scene, 1)
		return
	if not await walk(scene, route("res://tests/fixtures/l16_exit_dragon_room.json"), "to prop 241"):
		await stop(scene, 1)
		return
	var room = scene.get_node("L16DragonRoom")
	scene.camera.look_at(room.DRAGON_AT, Vector3.UP)
	await process_frame
	await process_frame
	if not check(room.aimed(room.DRAGON_AT, 180.0), "aimed at prop 241 from %s" % scene.player.position):
		await stop(scene, 1)
		return
	await click()
	if not check(bool(room.state().chopped), "the click chops the dragon"):
		await stop(scene, 1)
		return
	scene.progression.change_scene_enabled = false
	var before: int = scene.progression.level_changes.size()
	if not await walk(scene, route("res://tests/fixtures/l16_exit_pad.json"), "onto control 74"):
		await stop(scene, 1)
		return
	await process_frame
	await process_frame
	var changes: Array = scene.progression.level_changes
	var requested: bool = changes.size() > before and int(changes[-1].level) == 17 and int(changes[-1].selector) == 1
	var pad_ok: bool = requested and bool(room.state().pad_seen) and scene.area_id == "L16_CA" and not room.relocates_player()
	if not check(pad_ok, "the pad requests L17 arrival 1: %s %s" % [scene.player.position, changes]):
		await stop(scene, 1)
		return
	var trip: Dictionary = (changes[-1] as Dictionary).duplicate()
	scene.progression.change_scene_enabled = true
	scene.progression._change_level(trip)
	await scene_changed
	scene = current_scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	prepare(scene)
	var arrived: bool = scene.area_id == "L17_HC" and int(scene.start_selector) == 1 and scene.arrived_by_level_change
	arrived = arrived and scene.player.position.distance_to(Vector3(1434, 32, -7075)) < 2.0
	if not check(arrived, "L17 arrival 1: %s" % scene.player.position):
		await stop(scene, 1)
		return
	var save := "res://tmp/l17_arrival_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "L17 arrival save"):
		await stop(scene, 1)
		return
	if not check(scene._quickload_unrecorded(save).is_empty(), "L17 arrival reload"):
		await stop(scene, 1)
		return
	var kept: bool = scene.area_id == "L17_HC" and scene.player.position.distance_to(Vector3(1434, 32, -7075)) < 4.0
	if not check(kept, "reload keeps the L17 arrival"):
		await stop(scene, 1)
		return
	print("PASS earned oil chain -> centre pads -> mantle pose -> dragon pad -> L17 arrival 1")
	await stop(scene, 0)
