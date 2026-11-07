extends RefCounted
## Original Hive (L5_HC.MIX) item rows 5-9: the named audit gaps re-counted from the map bytes (AI_COMMS grok_backlog
## G18_hive_placements; tools/verify_hive_world_item_sources.py). Position is the native (x, height, -y): every row's
## height is its flat region floor inside the region volume, the same contract as hosted wax row 0 (hive_wax.gd).
## Rows 4 (31-Shift) and 10 (43-Deathstroke) carry placement flags 0x0402; the reader of bit 0x0400 is untraced
## (G34/G36), so they stay unhosted. Collected rows are pickup history, separate from carried copies.
const KEY := "hive_world_items"
const ROWS := [5, 6, 7, 8, 9]
const IDS := ["hive:item5:HlScrl", "hive:item6:Ltng_cr", "hive:item7:Ltng_cr", "hive:item8:Kelens_ring", "hive:item9:SS4"]
const DEFINITIONS := [148, 55, 55, 82, 139]
const IDENTITIES := [2071991751, 2228495501, 2228495501, 3856915368, 1520613813]
const NAMES := ["146-HlScrl", "56a-Ltng cr", "56a-Ltng cr", "80-Kelens ring", "137-SS4"]
const POSITIONS := [Vector3(-2149,-1387,-6758), Vector3(-2636,-539,-8943), Vector3(-2675,-539,-8947), Vector3(-3713,-951,-6966), Vector3(-2772,-811,-7989)]

static func initial() -> Dictionary: return {"version":1,"collected":[]}
static func valid(id: Variant) -> bool: return id is String and id in IDS
static func definition(id: String) -> int: return DEFINITIONS[IDS.find(id)] if id in IDS else -1
static func source_name(id: String) -> String: return NAMES[IDS.find(id)] if id in IDS else ""
static func validate(saved: Variant) -> String:
	if not saved is Dictionary or saved.size()!=2 or saved.get("version")!=1 or not saved.get("collected") is Array: return "Invalid Hive world-item history."
	var seen: Array = []
	for r in saved.collected:
		if not (r is int or r is float) or not is_finite(float(r)) or float(r)!=floorf(float(r)) or int(r) not in ROWS or int(r) in seen: return "Invalid Hive world-item row."
		seen.append(int(r))
	return ""
## Rows as ints (JSON loads them as floats).
static func rows_of(saved: Variant) -> Array:
	return saved.collected.map(func(r): return int(r)) if validate(saved).is_empty() else []
