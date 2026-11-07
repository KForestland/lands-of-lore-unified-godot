extends RefCounted
## HIVEW source action table through native A7D4C/A1E44.
## Caller supplies AC, the two-bit mode and one native-range random sample.
const ENTRIES := [[5,6,20,11],[5,1,20,12],[5,6,80,13],[5,1,80,14],[14,1,0,19],[14,6,0,20],[15,7,0,21]]
static func integer(value: Variant, limit: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value==floorf(value) and value>=0 and value<=limit
static func select(action: Variant, ac: Variant, mode: Variant, sample: Variant) -> Dictionary:
	if not integer(action,255) or int(action) not in [5,14,15] or not integer(ac,255) or not integer(mode,3) or not integer(sample,100): return {"error":"Invalid warrior action lookup."}
	var mask:=1 if int(mode)>1 else int(ac)
	var remaining:=int(sample)
	var first:=-1
	var matched:=-1
	for row in ENTRIES:
		if row[0]!=int(action): continue
		if first==-1: first=row[3]
		if (row[1]&mask)==0: continue
		remaining-=row[2]
		if remaining<0: return {"selector":row[3],"draws":1}
		if matched==-1: matched=row[3]
	return {"selector":matched if matched!=-1 else first,"draws":1}

static func mask_after_health(ac: Variant, previous: Variant, health: Variant, update_kind: Variant) -> Dictionary:
	if not integer(ac,255) or int(ac) not in [1,2,4] or not integer(previous,65535) or not integer(health,65535) or not integer(update_kind,255): return {"error":"Invalid warrior health mask update."}
	if previous==health: return {"mask":int(ac)}
	if ac==1 and health<=50: return {"mask":4 if update_kind==2 else 2}
	if ac!=1 and health>50: return {"mask":1}
	return {"mask":int(ac)}
