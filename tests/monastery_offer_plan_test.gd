extends SceneTree
func _initialize():
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://docs/monastery-offer-responses-source.json"))
	for row in source.cases:
		var plan := preload("res://scripts/lol2/monastery_offer.gd").plan(row.inputs.held,row.inputs.flags,int(row.inputs.power_orb))
		var immediate: Array = []
		var sequence := ""
		for effect in row.expected.effects:
			if effect[0] in ["movie","movie_flags"]:
				sequence = {550:"MOFF_RUNES",378:"MOFF_REFUSE",375:"MOFF_ORB"}[int(effect[2])]
				break
			var normalized: Array = effect.duplicate()
			if normalized.size()>1: normalized[1] = int(normalized[1])
			immediate.append(normalized)
		if int(plan.handled) != row.expected.handled or plan.effects != immediate or plan.sequence != sequence:
			push_error("Native Julian offer mismatch: "+str(row))
			quit(1)
			return
	print("PASS ",source.cases.size()," native Julian offer branches and immediate ordering")
	quit()
