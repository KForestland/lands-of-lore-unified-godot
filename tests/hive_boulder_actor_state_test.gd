extends SceneTree
const State=preload("res://scripts/lol2/hive_boulder_actor_state.gd")
const PathControl=preload("res://scripts/lol2/hive_path_control.gd")
func _initialize() -> void:
	var state:=State.initial()
	assert(State.validate(state).is_empty())
	var saved:=State.canonical(JSON.parse_string(JSON.stringify(state)))
	assert(saved==state)
	State.apply_group(state,6250)
	State.apply_group(state,6250)
	State.advance_animation(state.actors["30"],0.12345)
	assert(state.actors["31"].frame==0 and state.actors["30"].frame>0)
	State.apply_group(state,6806)
	State.apply_group(state,6250) # Repeated activation cannot erase the pending stop.
	for step in range(60):
		var restored:=State.canonical(JSON.parse_string(JSON.stringify(state)))
		for id in State.SPAWNS:
			assert(State.advance_animation(state.actors[id],0.01)==State.advance_animation(restored.actors[id],0.01))
		assert(state==restored and State.validate(state).is_empty())
	assert(not state.actors["30"].rolling and not state.actors["31"].rolling)
	var before:=state.duplicate(true)
	State.apply_group(state,6250)
	assert(state==before)
	for bad in [NAN,INF,-1.0]:
		assert(not State.advance_animation(state.actors["30"],bad) and state==before)
	var retired:=State.initial(true)
	State.apply_group(retired,6250)
	assert(retired==State.initial(true))
	for index in [12,-11,-1,0]:
		var route: Dictionary={"first":11,"count":13,"flags":0}
		var parsed: Dictionary=JSON.parse_string(JSON.stringify({"index":index}))
		assert(PathControl.advance_index(route,index,0)==PathControl.advance_index(route,parsed.index,0))
	assert(PathControl.advance_index({"first":11,"count":13,"flags":0},12,0).index==-11)
	assert(PathControl.advance_index({"first":11,"count":13,"flags":0},-1,0).index==0)
	var invalid:=state.duplicate(true)
	invalid.actors["30"].fraction=1
	assert(not State.validate(invalid).is_empty())
	invalid=state.duplicate(true)
	invalid.actors.erase("31")
	assert(not State.validate(invalid).is_empty())
	print("PASS saved independent boulder clocks, pending stop at every tick, repeated callback safety, retired legacy state and signed endpoint continuation")
	quit()
