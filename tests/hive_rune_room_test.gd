extends SceneTree
const Runes = preload("res://scripts/lol2/hive_rune_room.gd")
func _initialize() -> void:
	var report = JSON.parse_string(FileAccess.get_file_as_string("res://docs/hive-rune-room-checks.json"))
	assert(report is Dictionary and report.cases.size() == 88)
	for row in report.cases:
		var input: Dictionary = row.inputs
		var before := input.duplicate(true)
		var result := Runes.activate(input.room,int(input.hotspot),int(input.lights),input.flags,int(input.has_runes),input.held)
		assert(JSON.parse_string(JSON.stringify(result)) == row.expected, "Rune dispatch differs from native fixture: " + str(input))
		assert(input == before, "Planning must not mutate quest state before effects are applied")
	# A repeat copy consumes wax and grants another copy; only first-use calls disappear.
	var first := Runes.activate("RUNECL",0,1,{},0,"71-Wax")
	var repeat := Runes.activate("RUNECL",0,1,{},1,"71-Wax")
	assert(first.effects.slice(2) == repeat.effects)
	assert(repeat.effects[0] == ["consume_held"])
	assert(repeat.effects[1] == ["give_item","72-Wax runes",0])
	print("PASS: 88 rune-room effect plans match native dispatch; no input mutation; repeated wax copy retained")
	quit()
