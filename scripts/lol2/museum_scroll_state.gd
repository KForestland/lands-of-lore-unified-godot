extends RefCounted
## Placement receipts are separate from carried copies so consumed scrolls cannot respawn.
## Native settling evidence: AI_COMMS/codex_act1_review_20261028/scroll_native_settled_review.json.
const IDS := ["museum:item12:Spark_Scroll", "museum:item13:Spark_Scroll", "museum:item14:Healing_Scroll", "museum:item15:Healing_Scroll", "museum:item16:Summon_Scroll"]
const DEFINITIONS := [75, 75, 148, 148, 149]
const POSITIONS := [Vector3(-1937,30,-1168), Vector3(-1915,30,-1168), Vector3(-1870,30,-1168), Vector3(-1892,30,-1169), Vector3(-1937,30,-1163)]
static func initial() -> Dictionary:
	return {"version":1,"taken":[false,false,false,false,false],"consumed":[false,false,false,false,false]}
static func validate(value: Variant, carried: Array) -> String:
	var v: Variant = initial() if value == null else value
	if not v is Dictionary or v.size()!=3: return "Invalid Museum scroll checkpoint."
	var version: Variant = v.get("version")
	if not (version is int or version is float) or version!=1: return "Invalid Museum scroll version."
	for key in ["taken","consumed"]:
		if not v.get(key) is Array or v[key].size()!=5: return "Invalid Museum scroll receipts."
		for flag in v[key]:
			if not flag is bool: return "Invalid Museum scroll flag."
	for i in 5:
		if v.consumed[i] and not v.taken[i]: return "Scroll consumed before pickup."
		if carried.count(IDS[i]) != (1 if v.taken[i] and not v.consumed[i] else 0): return "Scroll receipt disagrees with inventory."
	return ""
static func canonical(value: Variant) -> Dictionary:
	if value == null: return initial()
	return {"version":1,"taken":value.taken.duplicate(),"consumed":value.consumed.duplicate()}
static func take(state: Dictionary, carried: Array, index: int) -> bool:
	if index<0 or index>=5 or state.taken[index] or IDS[index] in carried: return false
	state.taken[index]=true
	carried.append(IDS[index])
	return true
## Caller must first apply an admitted spell effect; this records consumption only.
static func record_consumption(state: Dictionary, carried: Array, index: int) -> bool:
	if index<0 or index>=5 or not state.taken[index] or state.consumed[index] or carried.count(IDS[index])!=1: return false
	state.consumed[index]=true
	carried.erase(IDS[index])
	return true
