extends RefCounted
const IDS := ["museum:item6:Fire_Crystal","museum:item5:Fire_Crystal","museum:item4:Fire_Crystal"]
static func initial() -> Dictionary: return {"version":1,"hits":0,"taken":[false,false,false]}
static func validate(v: Variant, carried: Array) -> String:
	if v == null: v = initial()
	if not v is Dictionary or v.size()!=3 or v.get("version")!=1 or not v.get("taken") is Array or v.taken.size()!=3: return "Invalid Museum crystal."
	var n = v.get("hits")
	if not (n is int or n is float) or not is_finite(float(n)) or n!=floorf(float(n)) or n<0 or n>3: return "Invalid crystal hit count."
	for i in 3:
		if not v.taken[i] is bool or (v.taken[i] and i>=int(n)): return "Crystal collected before release."
		if carried.count(IDS[i]) != (1 if v.taken[i] else 0): return "Crystal pickup receipt disagrees with inventory."
	return ""
static func canonical(v: Variant) -> Dictionary:
	if v == null: return initial()
	return {"version":1,"hits":int(v.hits),"taken":v.taken.duplicate()}
static func hit(s: Dictionary, mask0: int, mask2: int, amount: int) -> bool:
	if s.hits>=3 or (mask0&0x906)==0 or (mask2&4)==0 or amount<1: return false
	s.hits+=1
	return true
