extends RefCounted
## Conditions12..29 and32..37. Context comes from verified player/actor fields;
## geometry, current target binding and equipment provenance belong to the caller.
const EVALUATED := [12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,32,33,34,35,36,37]

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= minimum and value <= maximum

static func evaluate(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid player condition context."}
	for field in ["engaged","ready"]:
		if not context.get(field) is bool: return {"error":"Invalid player condition flag: "+field}
	for field in ["mode","stance","form","attribute_a","attribute_b","threshold","base","reserve"]:
		if not _integer(context.get(field),0,255): return {"error":"Invalid player condition byte: "+field}
	if not _integer(context.get("angle"),0,127) or not _integer(context.get("attack_modifier"),-128,127):
		return {"error":"Invalid condition angle or modifier."}
	for field in ["action_flags","action_flags2"]:
		if not _integer(context.get(field),0,4294967295): return {"error":"Invalid player action flags."}
	for field in ["attack_parts","defense_parts"]:
		var count := 4 if field == "attack_parts" else 3
		if not context.get(field) is Array or context[field].size() != count: return {"error":"Invalid comparison components."}
		for value in context[field]:
			if not _integer(value,0,4294967295): return {"error":"Invalid comparison component."}
	var found: Array[int] = []
	if context.engaged:
		if context.ready:
			if context.angle < 32: found.append(12)
			if context.angle > 96: found.append(13)
			var action := (((int(context.action_flags)>>9)^(int(context.action_flags)>>11))&1) != 0 or (int(context.action_flags2)&2) != 0
			found.append(22 if action else 23)
		else: found.append(14)
		var stance_index := [2,0,1].find(int(context.stance))
		if stance_index >= 0: found.append(19+stance_index)
	if context.mode < 4: found.append(15+int(context.mode))
	var form_index := [1,4,0,2,3,5].find(int(context.form))
	if form_index >= 0: found.append(24+form_index)
	var average: int = (int(context.attribute_a)+int(context.attribute_b))/2
	var threshold := maxi(1,int(context.threshold))
	if average > threshold: found.append(32)
	if average < threshold: found.append(33)
	var attack := int(context.attack_modifier)
	for value in context.attack_parts: attack += int(value)
	attack &= 4294967295
	var defense := 0
	for value in context.defense_parts: defense += int(value)
	defense &= 4294967295
	found.append(34 if attack > context.base else 35)
	found.append(36 if defense > context.reserve else 37)
	found.sort()
	return {"conditions":found,"evaluated":EVALUATED.duplicate(),"complete":false}
