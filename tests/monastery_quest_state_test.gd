extends SceneTree
const Room = preload("res://scripts/lol2/monastery_quest_state.gd")
const Quest = preload("res://scripts/lol2/act_one_quest_state.gd")
func _initialize() -> void:
	for left in [0,1,2,3,4]:
		for departed in [0,1]:
			var bacatta := Room.initial()
			bacatta.locals.Left_Village = left
			bacatta.flags["34"] = departed
			var expected: bool = not (left == 3 and departed == 1)
			assert(Room.enter_bacatta(bacatta) == expected)
			assert(bacatta.globals.GV_MET_BACATTA == int(expected))
	var state := Room.initial()
	assert(Room.validate(state).is_empty())
	assert(not Room.enter_library(state) and not Room.office_admitted(state))
	state.globals.GV_MET_BACATTA = 1
	assert(Room.enter_library(state) and Room.office_admitted(state))
	assert(not Room.cellar_admitted(state))
	state.flags["134"] = 1
	assert(Room.cellar_admitted(state))
	for blocker in ["144", "288"]:
		state.flags[blocker] = 1
		assert(not Room.office_admitted(state))
		state.flags[blocker] = 0
	state.flags["264"] = 1
	assert(not Room.office_admitted(state))
	state.globals.GV_HAS_RUNES = 1
	assert(Room.office_admitted(state))
	assert(not Room.dawn_present(state))
	state.locals.Gave_Dawn_Runes = 1
	assert(Room.dawn_present(state))
	for blocker in ["191", "269"]:
		var candidate := Room.initial()
		candidate.globals.GV_MET_BACATTA = 1
		candidate.flags[blocker] = 1
		assert(not Room.enter_library(candidate) and candidate.locals.Met_Dawn == 0)
	var translated := Room.initial()
	translated.globals.GV_MET_BACATTA = 1
	translated.globals.GV_RUNES_TRANSLATED = 1
	assert(Room.dawn_present(translated))
	translated.flags["266"] = 1
	assert(not Room.dawn_present(translated))
	var quest := Quest.initial()
	quest.monastery = state
	var restored = JSON.parse_string(JSON.stringify(quest))
	assert(Quest.validate(restored).is_empty())
	assert(Room.office_admitted(restored.monastery) and Room.cellar_admitted(restored.monastery))
	for bad in [-1, 2, 0.5, "1", null, true, INF, NAN]:
		var invalid: Dictionary = restored.duplicate(true)
		invalid.monastery.flags["144"] = bad
		assert(not Quest.validate(invalid).is_empty())
	restored.erase("monastery")
	assert(Quest.validate(restored).is_empty()) # older saves remain accepted
	print("PASS: monastery presence/admission branches, independent flag banks, JSON carry and malformed/legacy saves")
	quit()
