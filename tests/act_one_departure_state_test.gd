extends SceneTree
const State = preload("res://scripts/lol2/act_one_departure_state.gd")
func _initialize():
	for value in range(256):
		var s := State.initial()
		s.local55 = value
		var ok := State.begin(s)
		assert(ok == (value in [0,1]))
		if value == 0:
			assert(s.phase=="movie" and s.local55==1)
			State.advance(s,State.DURATION-0.01)
			assert(s.phase=="movie" and State.validate(s).is_empty())
			State.advance(s,0.02)
			assert(s.phase=="arrival" and s.elapsed==0)
		elif value == 1: assert(s.phase=="arrival")
		else: assert(s.local55==value and s.phase=="idle")
	assert(not State.validate({"local55":0,"phase":"movie","elapsed":1}).is_empty())
	assert(not State.validate({"local55":1,"phase":"movie","elapsed":State.DURATION}).is_empty())
	for value in range(256):
		var saved := State.initial()
		saved.local55 = value
		var loaded: Dictionary = JSON.parse_string(JSON.stringify(saved))
		if State.begin(loaded) != (value in [0,1]):
			push_error("JSON round-trip departure admission mismatch for %s" % value)
			quit(1)
			return
	print("PASS: all256 original and JSON-round-tripped local55 values, first/repeat effects, full audio duration and malformed state")
	quit()
