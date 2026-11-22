extends "res://tests/l12_logs_approach_earned_test.gd"
## BJ09: greenhouse chain save -> walk the open steps to the NE door.
## The +55 and +35 rises are player jumps. The lift stays the existing adapter.
const ARRIVAL := Vector3(16082, 132, 3886)

func travel(scene: Node, legs: Array) -> bool:
	for index in legs.size():
		var leg: Dictionary = legs[index]
		var at: Array = leg["at"]
		var goal := Vector3(float(at[0]), 0.0, float(at[1]))
		var min_y := float(leg["min_y"])
		var jump_after_z := float(leg["jump_after_z"])
		var jump_below := float(leg["jump_below"])
		var settle_z := float(leg["settle_z"])
		var hopped := false
		var prior: Vector3 = scene.player.position
		var stalled := 0
		var jumps := 0
		var reached := false
		var max_y: float = scene.player.position.y
		for tick in 1600:
			if scene.player.position.distance_to(ARRIVAL) < 8.0:
				print("LIFT ", index, " ", scene.player.position, " region ", scene.progression.region_at(scene.player.position))
				return true
			if scene.resets != 0:
				print("RESET ", index, " ", scene.player.position, " region ", scene.progression.region_at(scene.player.position), " maxy ", max_y)
				return false
			if scene.player.is_on_floor():
				if not await fight_nearby(scene):
					print("TOWER FIGHT ", scene.player.position, " region ", scene.progression.region_at(scene.player.position))
					return false
			var pos: Vector3 = scene.player.position
			if pos.y > max_y:
				max_y = pos.y
			var steering := goal - pos
			steering.y = 0.0
			var flat := steering.length()
			if flat < 7.0 and scene.player.is_on_floor() and pos.y >= min_y:
				print("AT ", index, " ", pos, " region ", scene.progression.region_at(pos), " maxy ", max_y)
				reached = true
				break
			if scene.player.is_on_floor() and pos.distance_to(prior) < 0.05:
				stalled += 1
			else:
				stalled = 0
			prior = pos
			if jump_after_z < -1.0 and not hopped and scene.player.is_on_floor() and pos.y < jump_below and pos.z < jump_after_z:
				var launched: bool = scene.request_jump()
				hopped = true
				jumps += 1
				print("HOP ", index, " ", pos, " launched ", launched, " region ", scene.progression.region_at(pos))
			elif stalled == 25 and scene.player.is_on_floor() and settle_z > -1.0:
				scene.request_jump()
				jumps += 1
				stalled = 0
			if jumps >= 4 and stalled >= 25:
				print("STALL ", index, " ", pos, " region ", scene.progression.region_at(pos), " goal ", at, " maxy ", max_y)
				return false
			if settle_z < -1.0 and hopped and not scene.player.is_on_floor() and pos.z < settle_z:
				steering = Vector3.ZERO
			elif flat > 0.001:
				steering = steering.normalized()
			scene.move_grounded(steering, 1.0 / 60.0)
			await physics_frame
			if tick % 120 == 0:
				print("STEP ", index, " ", tick, " ", scene.player.position, " region ", scene.progression.region_at(scene.player.position), " floor ", scene.player.is_on_floor(), " maxy ", max_y)
		if not reached and scene.player.position.distance_to(ARRIVAL) >= 8.0:
			print("SHORT ", index, " ", scene.player.position, " region ", scene.progression.region_at(scene.player.position), " maxy ", max_y)
			return false
	return true

func run():
	Engine.time_scale = 4
	Engine.physics_ticks_per_second = 240
	var path := "res://tmp/l16_greenhouse_chain_earned_save.json"
	if not check(FileAccess.file_exists(path), "earned greenhouse chain save"):
		quit(1)
		return
	var input = Save.read_save(path, "lol2-restoration-map-L16_CA")
	if not check(input.error.is_empty(), str(input.error)):
		quit(1)
		return
	var scene = load("res://scenes/lol2/maps/L16_CA.tscn").instantiate()
	scene.adapter_exit_seeds = false
	root.add_child(scene)
	current_scene = scene
	for i in 1500:
		await process_frame
		if scene.ready_for_review:
			break
	if not check(scene.apply_save(input.state).is_empty(), "earned greenhouse chain input"):
		quit(1)
		return
	prepare(scene)
	var tower = scene.get_node("L16NeTower")
	if not check(bool(scene.get_node("L16Greenhouse").state().opened), "doors already open"):
		quit(1)
		return
	var lip: Array = [[2287.5, -1018.0], [2287.5, -1045.0]]
	if not await walk(scene, lip, "hourglass to the jump runway"):
		quit(1)
		return
	print("RUNWAY ", scene.player.position, " region ", scene.progression.region_at(scene.player.position), " resets ", scene.resets)
	var legs: Array = [
		{"at": [2290.0, -1160.0], "min_y": 120.0, "jump_after_z": -1076.0, "jump_below": 100.0, "settle_z": 0.0},
		{"at": [2288.0, -1360.0], "min_y": 115.0, "jump_after_z": 0.0, "jump_below": 0.0, "settle_z": 0.0},
		{"at": [2288.0, -1500.0], "min_y": 90.0, "jump_after_z": 0.0, "jump_below": 0.0, "settle_z": 0.0},
		{"at": [2288.0, -1620.0], "min_y": 130.0, "jump_after_z": -1572.0, "jump_below": 120.0, "settle_z": -1620.0},
		{"at": [2288.0, -1750.0], "min_y": 20.0, "jump_after_z": 0.0, "jump_below": 0.0, "settle_z": 0.0},
		{"at": [2288.0, -1911.0], "min_y": 20.0, "jump_after_z": 0.0, "jump_below": 0.0, "settle_z": 0.0},
		{"at": [2288.0, -2100.0], "min_y": 20.0, "jump_after_z": 0.0, "jump_below": 0.0, "settle_z": 0.0},
		{"at": [2288.0, -2300.0], "min_y": 20.0, "jump_after_z": 0.0, "jump_below": 0.0, "settle_z": 0.0},
		{"at": [2288.0, -2500.0], "min_y": 20.0, "jump_after_z": 0.0, "jump_below": 0.0, "settle_z": 0.0},
		{"at": [2288.0, -2700.0], "min_y": 20.0, "jump_after_z": 0.0, "jump_below": 0.0, "settle_z": 0.0},
		{"at": [2288.0, -2882.0], "min_y": 20.0, "jump_after_z": 0.0, "jump_below": 0.0, "settle_z": 0.0},
		{"at": [2292.0, -2950.0], "min_y": 20.0, "jump_after_z": 0.0, "jump_below": 0.0, "settle_z": 0.0}
	]
	var walked: bool = await travel(scene, legs)
	print("TOWER ", scene.player.position, " region ", scene.progression.region_at(scene.player.position), " at_doors ", tower.state().at_doors, " walked ", walked, " resets ", scene.resets)
	if not walked or scene.resets != 0 or not bool(tower.state().at_doors):
		scene.queue_free()
		await process_frame
		quit(1)
		return
	var stayed: bool = scene.player.position.distance_to(ARRIVAL) < 8.0
	if not check(stayed, "lift adapter reached the upper floor"):
		quit(1)
		return
	var save := "res://tmp/l16_ne_tower_chain_earned_save.json"
	if not check(scene._quicksave_unrecorded(save).is_empty(), "NE tower chain save"):
		quit(1)
		return
	if not check(scene._quickload_unrecorded(save).is_empty(), "NE tower chain reload"):
		quit(1)
		return
	tower = scene.get_node("L16NeTower")
	await process_frame
	var kept: bool = bool(tower.state().at_doors) and scene.player.position.distance_to(ARRIVAL) < 8.0 and scene.resets == 0
	if not check(kept, "save keeps the upper floor"):
		quit(1)
		return
	print("UPPER ", scene.player.position, " region ", scene.progression.region_at(scene.player.position))
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("PASS earned greenhouse chain -> NE tower steps -> lift adapter -> upper floor save/reload")
	quit(0 if failures == 0 else 1)
