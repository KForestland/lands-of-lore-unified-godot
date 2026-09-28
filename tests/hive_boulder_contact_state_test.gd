extends SceneTree
const State=preload("res://scripts/lol2/hive_boulder_contact_state.gd")
const Controller=preload("res://scripts/lol2/hive_boulders.gd")
func _initialize() -> void:
	assert(Controller!=null and State.validate(State.initial()).is_empty())
	var saved:={"version":1,"angle":65535,"magnitude":72.5}
	assert(State.canonical(JSON.parse_string(JSON.stringify(saved)))==saved)
	for key in ["version","angle","magnitude"]:
		var bad:=saved.duplicate();bad.erase(key);assert(not State.validate(bad).is_empty())
		for value in [true,"1",NAN,-1]:
			bad=saved.duplicate();bad[key]=value;assert(not State.validate(bad).is_empty())
	for value in [255.01,INF]:
		var bad:=saved.duplicate();bad.magnitude=value;assert(not State.validate(bad).is_empty())
	print("PASS: contact controller parses and partial impulse roundtrip rejects malformed saves")
	quit()
