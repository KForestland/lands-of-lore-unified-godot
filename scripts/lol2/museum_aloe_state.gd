extends RefCounted
## Original placed items19/20; one harvest each, unlike renewable Cave plants.
const IDS := ["museum:item19:Cave_Aloe","museum:item20:Cave_Aloe"]
const DEFINITIONS := [110,110]
const POSITIONS := [Vector3(-1399,-183.36746215820312,-1096),Vector3(-1585,-170,-1102)]
static func initial() -> Dictionary: return {"version":1,"taken":[false,false]}
static func validate(value: Variant, carried: Array, spent: Array) -> String:
	var v: Variant=initial() if value==null else value
	if not v is Dictionary or v.size()!=2: return "Invalid Museum Aloe checkpoint."
	var version: Variant=v.get("version")
	if not (version is int or version is float) or version!=1: return "Invalid Museum Aloe version."
	if not v.get("taken") is Array or v.taken.size()!=2: return "Invalid Museum Aloe receipts."
	for i in 2:
		if not v.taken[i] is bool: return "Invalid Museum Aloe flag."
		if carried.count(IDS[i])+spent.count(IDS[i])!=(1 if v.taken[i] else 0): return "Museum Aloe receipt disagrees with inventory."
	return ""
static func canonical(value: Variant) -> Dictionary:
	return initial() if value==null else {"version":1,"taken":value.taken.duplicate()}
static func take(state: Dictionary, carried: Array, index: int) -> bool:
	if index<0 or index>=2 or state.taken[index] or IDS[index] in carried: return false
	state.taken[index]=true
	carried.append(IDS[index])
	return true
