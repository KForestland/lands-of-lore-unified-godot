extends SceneTree
const State=preload("res://scripts/lol2/cave_guard_encounter_state.gd")
func _initialize() -> void:
	var src:=State.Sequence.source();var geometry:=State.Movement.source()
	var state:=State.initial(src,geometry)
	assert(State.validate(state,src,geometry).is_empty())
	State.release_crossbow_definition(state)
	assert(state.definition_flags["28"]==0 and State.validate(state,src,geometry).is_empty())
	var group: Array=[{"group":56,"commands":src.groups["56"].commands}]
	State.apply(state,src,geometry,group,0)
	assert(state.definition_flags["28"]==2 and State.validate(state,src,geometry).is_empty())
	State.release_crossbow_definition(state)
	assert(state.definition_flags["28"]==0 and State.validate(state,src,geometry).is_empty())
	var saved: Dictionary=JSON.parse_string(JSON.stringify(state))
	assert(State.validate(saved,src,geometry).is_empty())
	assert(State.canonical(saved)==state)
	State.apply(state,src,geometry,group,0)
	assert(state.definition_flags["28"]==2 and State.validate(state,src,geometry).is_empty())
	var bad: Dictionary=state.duplicate(true);bad.definition_flags["28"]=0
	assert(not State.validate(bad,src,geometry).is_empty())
	bad=state.duplicate(true);bad.definition_release_at=99999
	assert(not State.validate(bad,src,geometry).is_empty())
	var legacy:=State.initial(src,geometry);legacy.erase("definition_release_at")
	State.apply(legacy,src,geometry,group,0)
	assert(State.validate(legacy,src,geometry).is_empty())
	assert(State.canonical(legacy).definition_release_at== -1)
	print("PASS shared crossbow definition: property26/27 ordering, release before/after group56, JSON continuation, legacy receipt migration, malformed order rejected; no inventory grant/removal.")
	quit()
