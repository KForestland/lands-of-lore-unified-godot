extends RefCounted
## Source RUNES/RUNECL dispatch as an ordered effect plan.
## Detached until Hive admission, item matching and remaining callbacks are bound.
## Caller owns effect execution/persistence; planning never mutates the quest bank.
static func activate(room: String, hotspot: int, lights: int, flags: Dictionary, has_runes: int, held: String) -> Dictionary:
	var effects: Array = []
	var handled := 0
	if room == "RUNES":
		if hotspot == 1:
			effects = [["set_flag",286],["end_room"]]
			handled = 1
		elif lights == 0:
			effects = [["movie",2,26,24]]
			handled = 1
		elif hotspot == 3:
			effects = [["unresolved_callback","RUNES:81c",256]]
			handled = 1
		elif hotspot == 2:
			if flags.get("8",0) == 0:
				effects.append_array([["set_flag",8],["movie",2,64,24]])
			effects.append_array([["set_flag",286],["next_room","RUNECL_"],["end_room"]])
			handled = 1
		elif hotspot == 4 and flags.get("7",0) == 0:
			effects = [["remove_overlay","RUNES2_"],["named_movie","RUNES3_"],
				["give_item","66-Ancients stn",0],["set_flag",7],["movie",100,2,24]]
			handled = 1
	elif room == "RUNECL":
		if hotspot == 0:
			var line := 35
			if held.is_empty(): line = 51
			elif held == "???": line = 24
			elif held == "71-Wax":
				if has_runes == 0:
					effects.append_array([["award_experience","fighting",200],
						["award_experience","magic",200]])
				effects.append_array([["consume_held"],["give_item","72-Wax runes",0],
					["set_global","GV_HAS_RUNES",1]])
				line = 66
			effects.append(["movie",2,line,24])
			handled = 1
		elif hotspot == 1:
			effects = [["movie",2,62,24]] # Native handler still returns zero.
	return {"handled":handled,"effects":effects}
