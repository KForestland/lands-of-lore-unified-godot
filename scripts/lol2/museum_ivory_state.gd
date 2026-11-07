extends RefCounted
## Two independent, nonconsumable placed items. 0=intact, 1=broken/item available, 2=collected.
## Source durability2 crosses threshold1 on any positive hit; repeat hits never duplicate a pickup.
const IDS := ["museum:item17:Ivory_Chip", "museum:item18:Ivory_Chip"]
static func initial() -> Dictionary: return {"version":1,"stages":[0,0]}
static func validate(value: Variant, carried: Variant = null) -> String:
	if not value is Dictionary or value.size()!=2 or not value.has("version") or not value.has("stages"): return "Invalid ivory-chip checkpoint."
	var version = value.version
	if not (version is int or version is float) or not is_finite(float(version)) or version!=1: return "Invalid ivory-chip version."
	if not value.stages is Array or value.stages.size()!=2: return "Invalid ivory-chip stages."
	for i in 2:
		var stage = value.stages[i]
		if not (stage is int or stage is float) or not is_finite(float(stage)) or stage<0 or stage>2 or stage!=int(stage): return "Invalid ivory-chip stage."
		if carried!=null:
			if not carried is Array or carried.count(IDS[i])!=(1 if stage==2 else 0): return "Ivory-chip receipt and inventory disagree."
	return ""
static func hit(state: Dictionary, index: int, damage: int) -> bool:
	if index<0 or index>=2 or damage<=0 or state.stages[index]!=0: return false
	state.stages[index]=1
	return true
static func take(state: Dictionary, index: int, carried: Array, capacity: int) -> bool:
	if index<0 or index>=2 or state.stages[index]!=1 or IDS[index] in carried or carried.size()>=capacity: return false
	carried.append(IDS[index]);state.stages[index]=2
	return true
