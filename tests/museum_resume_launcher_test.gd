extends SceneTree
const Save = preload("res://scripts/lol2/museum_save.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var path := "user://tests/launcher_museum_%d.json" % Time.get_ticks_usec()
	var cfg := path + ".cfg"
	var state := {"format":Save.FORMAT,"version":1,"checkpoint":{
		"version":1,"introduction_complete":true,"collected":[],"equipped_item":"",
		"sword":{"started":false,"elapsed":0,"idle_elapsed":0,"collected":false},
		"gate":{"target_open":false,"progress":0}},
		"player":{"position":[-4222,32,-1050],"yaw":0.3,"pitch":-0.2}}
	assert(Save.write_save(path,state).is_empty())
	var gate = load("res://scenes/lol2/original_game_gate.tscn").instantiate()
	gate.settings_path = cfg
	gate.museum_save_path = path
	root.add_child(gate)
	current_scene = gate
	gate.path_field.text = ""
	gate._verify_and_start(true)
	assert(not get_meta("original_game_verified") and not has_meta("lol2_museum_resume"))
	gate.path_field.text = "~/lol2_out/museum_capture_20260913/game/LOLG.EXE"
	gate._verify_and_start(true)
	await process_frame
	await process_frame
	assert(current_scene != null and current_scene.get_script().resource_path.ends_with("museum_walkthrough.gd"))
	assert(get_meta("original_game_verified"))
	assert(current_scene.introduction_state == "complete" and not is_instance_valid(current_scene.introduction))
	# 2026-10-31 pin refresh (lead decision): the saved point (-4222,32,-1050) now settles 15.5 units north on arrival, the body
	# (radius 15) pushed out of the wall it was saved against; measured (-4221.455, 32.047, -1034.54) in the gate flow headless.
	assert(current_scene.player.position.distance_to(Vector3(-4221.455,32.05,-1034.54)) < 1)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(cfg)
	print("Launcher resume passed: original verification required, museum save routed and applied without replaying intro")
	quit()
