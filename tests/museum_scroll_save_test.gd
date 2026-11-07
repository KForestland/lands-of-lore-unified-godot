extends SceneTree
const S = preload("res://scripts/lol2/museum_scroll_state.gd")
const Save = preload("res://scripts/lol2/museum_save.gd")
func _initialize() -> void:
	var state := {"format":Save.FORMAT,"version":1,"player":{"position":[0,0,0],"yaw":0,"pitch":0},"checkpoint":{"version":1,"introduction_complete":true,"collected":[],"equipped_item":"","equipped_armor":"","sword":{"started":false,"collected":false,"elapsed":0},"gate":{"target_open":false,"progress":0}}}
	assert(Save.validate(state).is_empty())
	state.checkpoint.museum_scrolls=S.initial()
	assert(S.take(state.checkpoint.museum_scrolls,state.checkpoint.collected,0))
	assert(S.take(state.checkpoint.museum_scrolls,state.checkpoint.collected,1))
	assert(Save.validate(state).is_empty())
	var missing := state.duplicate(true); missing.checkpoint.erase("museum_scrolls")
	assert(not Save.validate(missing).is_empty())
	assert(S.record_consumption(state.checkpoint.museum_scrolls,state.checkpoint.collected,0))
	assert(Save.validate(state).is_empty())
	DirAccess.make_dir_recursive_absolute("user://tests")
	var path := "user://tests/museum_scroll_save.json"
	assert(Save.write_save(path,state).is_empty())
	var roundtrip = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(Save.validate(roundtrip).is_empty())
	assert(roundtrip.checkpoint.museum_scrolls.consumed[0] and roundtrip.checkpoint.collected.size()==1)
	var original := FileAccess.get_file_as_string(path)
	var malformed := state.duplicate(true); malformed.checkpoint.museum_scrolls.taken[1]=false
	assert(not Save.write_save(path,malformed).is_empty())
	assert(FileAccess.get_file_as_string(path)==original)
	print("PASS Museum scroll save legacy, two copies, consumption, roundtrip and rejected-write preservation")
	quit()
