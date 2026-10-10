extends RefCounted
## Native A4C6C decision-entry fields. Caller supplies source action/last frame.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")

static func evaluate(saved: Variant) -> Dictionary:
	if not saved is Dictionary: return {"error":"Invalid animation snapshot."}
	for field in ["action","frame","last","b4"]:
		if not Numbers._integer(saved.get(field),255): return {"error":"Invalid animation field: "+field}
	var frame := int(saved.frame)
	var terminal := frame==0 if (int(saved.b4)&8)!=0 else frame>=int(saved.last) and frame!=255
	return {"action":int(saved.action),"terminal":terminal,"mode":2,"behavior":0}
