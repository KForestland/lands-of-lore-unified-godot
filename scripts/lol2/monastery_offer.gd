extends RefCounted
## Source MOFF06ea immediate effects; timed translation effects remain in Speech.
static func plan(held: String, flags: Dictionary, power_orb: int) -> Dictionary:
	var result := {"handled":false,"effects":[],"sequence":""}
	if not held.is_empty():
		result.handled = true
		if held == "72-Wax runes":
			result.effects.append(["clear_flag",265])
			if flags.get("140",0) == 0:
				result.effects.append_array([["set_flag",140],["consume_held"]])
				result.sequence = "MOFF_RUNES"
		elif flags.get("140",0) == 0:
			result.sequence = "MOFF_REFUSE"
	elif flags.get("143",0) == 0 and flags.get("283",0) == 0 and power_orb != 0:
		result.handled = true
		result.effects.append(["set_flag",143])
		result.sequence = "MOFF_ORB"
	return result
