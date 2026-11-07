extends SceneTree
const Responses := preload("res://scripts/lol2/liz_room_responses.gd")
const State := preload("res://scripts/lol2/monastery_quest_state.gd")
const Speech := preload("res://scripts/lol2/monastery_conversation.gd")
func _initialize() -> void:
	var state := State.initial()
	state.room = "LIZ"; state.flags["268"] = 1
	assert(State.validate(state).is_empty()) # legacy saves omit new history fields
	var heard: Array = []
	for visit in 2:
		Responses.reset_triggers(state)
		for hotspot in range(1,5):
			var line := Responses.choose(state,hotspot)
			assert(line in Responses.LINES and line not in heard)
			heard.append(line)
			state.conversation = {"sequence":"LIZ_QUIP_%d" % line,"cursor":0,"elapsed":0.0}
			assert(State.validate(state).is_empty())
			assert(Speech.room_for(state.conversation.sequence) == "LIZ")
			var before := state.duplicate(true)
			assert(Responses.choose(state,hotspot) == 0 and state == before)
			var decoded: Dictionary = JSON.parse_string(JSON.stringify(state))
			assert(State.validate(decoded).is_empty())
			assert(Responses.choose(decoded,hotspot) == 0)
			Speech.advance(state,Speech.duration(state.conversation.sequence,0))
			assert(not Speech.active(state.conversation))
	assert(heard.size() == 8)
	Responses.reset_triggers(state)
	assert(Responses.choose(state,1) in Responses.LINES) # exhausted history starts new cycle
	for invalid in [-1,4096,0.5,"wrong",INF]:
		var bad := State.initial(); bad.liz_response_mask = invalid
		assert(not State.validate(bad).is_empty())
	var forged := State.initial(); forged.room="LIZ"; forged.flags["268"]=1
	forged.conversation={"sequence":"LIZ_QUIP_56","cursor":0,"elapsed":0.0}
	assert(not State.validate(forged).is_empty())
	assert(load("res://scripts/lol2/monastery_rooms.gd") != null)
	assert(load("res://scripts/lol2/monastery_room_view.gd") != null)
	print("PASS liz_response_state: four once-per-entry hotspots, eight nonrepeating native lines, next-cycle reset, legacy and active JSON roundtrip, invalid/forged histories refused")
	quit()
