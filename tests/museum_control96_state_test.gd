extends SceneTree
const State=preload("res://scripts/lol2/museum_control96_state.gd")
func _initialize() -> void:
	var s:=State.initial()
	assert(State.validate(s).is_empty())
	assert(State.admit(s));assert(not State.admit(s))
	assert(State.advance(s,0.5).is_empty())
	var saved:=State.canonical(JSON.parse_string(JSON.stringify(s)))
	assert(State.validate(saved).is_empty())
	assert(State.advance(saved,1.3)==["activate179"])
	assert(saved.stage==1 and saved.state==1 and not saved.spawned30)
	assert(State.advance(saved,41.0/15.0)==["spawn30"])
	assert(State.validate(saved).is_empty() and not saved.present)
	assert(State.advance(saved,20).is_empty())
	for field in ["stage","elapsed","state"]:
		var bad=saved.duplicate(true);bad[field]=NAN;assert(not State.validate(bad).is_empty())
	var bad=saved.duplicate(true);bad.latched=false;assert(not State.validate(bad).is_empty())
	print("PASS museum_control96_state_test");quit()
