extends SceneTree
## Fire Pit source roach. Actor 44 is definition 4 at the native pit coordinate.
const State = preload("res://scripts/lol2/cave_roach_population_state.gd")
func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(State.SOURCE))
	var source: Dictionary = parsed
	var row: Dictionary = {}
	for item in source.actors:
		var actor: Dictionary = item
		if int(actor.actor) == 44:
			row = actor
	assert(not row.is_empty())
	var position: Array = row.position
	assert(int(position[0]) == -155 and int(position[1]) == -265 and int(position[2]) == -14685)
	assert(int(row.health) == 10)
	var named: Array = State.audio_actors()
	var found: Dictionary = {}
	var giants := 0
	for item2 in named:
		var actor2: Dictionary = item2
		if int(actor2.definition) != 4:
			giants += 1
		if int(actor2.actor) == 44:
			found = actor2
	assert(giants == 0 and int(found.definition) == 4 and int(found.health) == 10)
	var state: Dictionary = State.initial()
	var live: Array = state.actors["44"].position
	assert(int(live[0]) == -155 and int(live[1]) == -265 and int(live[2]) == -14685)
	assert(int(state.actors["44"].health) == 10)
	print("PASS: Fire Pit source roach 44 is definition 4 at (-155, -265, -14685)")
	quit()
