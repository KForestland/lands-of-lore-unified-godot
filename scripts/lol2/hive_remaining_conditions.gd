extends RefCounted
## Remaining six predicates. Distances are supplied native helper results;
## this component does not calculate geometry or bind live targets.
const EVALUATED := [0,9,30,31,41,43]
const Validation = preload("res://scripts/lol2/hive_player_conditions.gd")
var _flags: Array = []

static func _signed32(value: int) -> int:
	return ((value + 2147483648) & 4294967295) - 2147483648

func evaluate(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid condition context."}
	for field in ["selected","geometry41_enabled"]:
		if not context.get(field) is bool: return {"error":"Invalid condition flag: "+field}
	for field in ["distance9","distance41"]:
		if not Validation._integer(context.get(field),-2147483648,2147483647): return {"error":"Invalid distance: "+field}
	for field in ["radius9","radius41","size_definition","effect_id"]:
		if not Validation._integer(context.get(field),0,255): return {"error":"Invalid condition byte: "+field}
	for field in ["health_current","secondary_current","health_max","secondary_max"]:
		var minimum := 1 if field.ends_with("_max") else 0
		if not Validation._integer(context.get(field),minimum,4294967295): return {"error":"Invalid percentage input: "+field}
	if _flags.is_empty():
		var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_attack/effect_condition_flags.json"))
		if not source is Dictionary or source.get("version") != 1 or not source.get("flags") is Array or source.flags.size() != 256:
			return {"error":"Invalid effect condition source."}
		for value in source.flags:
			if not Validation._integer(value,0,255): return {"error":"Invalid effect condition flag."}
		_flags = source.flags.duplicate()
	var found: Array[int] = []
	if context.selected: found.append(0)
	if _signed32(int(context.distance9) - (int(context.radius9)<<21)) <= 0: found.append(9)
	for pair in [["health",30],["secondary",31]]:
		var numerator := (int(context[pair[0]+"_current"])*100)&4294967295
		var percentage: int = numerator / int(context[pair[0]+"_max"])
		if _signed32(percentage) < 50: found.append(pair[1])
	if context.geometry41_enabled and _signed32(int(context.distance41) - ((int(context.radius41)<<5)+(int(context.size_definition)>>1))) < 0:
		found.append(41)
	if (int(_flags[int(context.effect_id)])&192) != 0: found.append(43)
	return {"conditions":found,"evaluated":EVALUATED.duplicate(),"complete":false}
