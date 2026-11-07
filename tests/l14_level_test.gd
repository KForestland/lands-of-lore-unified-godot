extends "res://tests/act2_level_transition_case.gd"
func specification() -> Dictionary:
	return {"area": "L14_HT", "scene": "res://scenes/lol2/maps/L14_HT.tscn", "start": Vector3(2576,32,-3181),
		"region": 863, "group": 1462, "level": 8, "selector": 3,
		"destination": "res://scenes/lol2/darker_jungle.tscn", "position": Vector3(868,48,2180), "yaw": -TAU * 61895.0 / 65536.0}

func run() -> void:
	# Selector 3 is the exit's own region: being placed there must not count as crossing into it.
	set_meta("lol2_map_start_selector", 3)
	set_meta("lol2_level_change", true)
	var arrival = load("res://scenes/lol2/maps/L14_HT.tscn").instantiate()
	root.add_child(arrival)
	arrival.player.set_physics_process(false)
	arrival.progression.change_scene_enabled = false
	for i in 3: await physics_frame
	check(arrival.progression.current_region == 4176 and arrival.progression.level_changes.is_empty(), "arrival on exit region does not bounce back")
	arrival.queue_free()
	await process_frame
	await super.run()
