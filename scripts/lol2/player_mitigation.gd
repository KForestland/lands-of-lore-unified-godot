extends RefCounted
## Native 89E7C list/defense dispatch. Caller supplies resident item descriptors,
## exact UI mode (including transitions), boosted/optional flags and stat parts.
const Numbers = preload("res://scripts/lol2/save_value_rules.gd")

static func build(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid mitigation context."}
	for field in ["form","ui_mode"]:
		if not Numbers.integer(context.get(field),255): return {"error":"Invalid mitigation mode."}
	for field in ["boosted","optional"]:
		if not context.get(field) is bool: return {"error":"Invalid mitigation flag."}
	if not Numbers.integer(context.get("bypass"),3): return {"error":"Invalid mitigation bypass."}
	if not context.get("defense_parts") is Array or context.defense_parts.size()!=3: return {"error":"Invalid defense parts."}
	var scalar := 0
	for part in context.defense_parts:
		if not Numbers.integer(part,65535): return {"error":"Unsupported defense part."}
		scalar+=int(part)
	if scalar>65535: return {"error":"Unsupported defense total."}
	if not context.get("slots") is Array or context.slots.size()!=6: return {"error":"Invalid equipment slots."}
	var descriptors: Array=[]
	var occupied := 0
	for slot in context.slots:
		if slot==null: continue
		occupied+=1
		if not slot is Array or slot.size()>4: return {"error":"Invalid equipment descriptor."}
		for entry in slot:
			if not entry is Array or entry.size()!=3: return {"error":"Invalid equipment mitigation entry."}
			if not Numbers.integer(entry[0],255) or not Numbers.integer(entry[1],65535) or not Numbers.integer(entry[2],65535): return {"error":"Invalid equipment mitigation values."}
		if int(context.form)==0: descriptors.append(slot.duplicate(true))
	if int(context.form)==0: descriptors.append([[7,1024,4],[7,2048,4]])
	elif int(context.ui_mode)!=3: descriptors.append([[2,0,4],[7,2048,4],[7,512,4]])
	elif context.boosted: descriptors.append([[7,1024,4],[7,512,4],[6,0,4]])
	else: descriptors.append([[7,1024,4],[7,512,4],[5,0,4],[2,0,3]])
	if context.optional:
		# Native eighth-pointer terminator overlaps these operation bytes.
		descriptors.append([[0 if occupied==6 and int(context.form)==0 else 5,0,5]])
	if int(context.bypass)!=0: scalar=0
	if (int(context.bypass)&1)!=0: descriptors=[]
	return {"scalar":scalar,"descriptors":descriptors}
