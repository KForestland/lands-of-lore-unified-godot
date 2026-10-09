extends RefCounted
## Renewable Jungle harvest items (jungle_harvest_source.json). Plants and trees regrow, so supply is unbounded over
## time; carried ids stay unique and the catalog finite through fixed pools sized to every plant/tree being harvested
## at once (Aloe 8x3 + barrel1464's 3, sap 8x3). A harvest takes the lowest pool id that is not carried. A consumed id
## is renewable: re-harvesting it removes it from the item-effects spent history (spent ids must never be carried).
const ALOE_PREFIX := "jungle:aloe_plant:Aloe_"
const SAP_PREFIX := "jungle:sap_tree:Ironwood_sap_"
const ALOE_COUNT := 27
const SAP_COUNT := 24
const ALOE_NAME := "107-Aloe"
const SAP_NAME := "109-Ironwod sap"
const ROOT := "res://assets/lol2/generated/jungle_harvest/"

static func pool(kind: String) -> Array:
	var out: Array = []
	var prefix := ALOE_PREFIX if kind == "aloe" else SAP_PREFIX
	for i in range(1, (ALOE_COUNT if kind == "aloe" else SAP_COUNT) + 1): out.append(prefix + str(i))
	return out
static func all() -> Array: return pool("aloe") + pool("sap")
static func kind(id: Variant) -> String:
	if not id is String: return ""
	for k in ["aloe","sap"]:
		var prefix := ALOE_PREFIX if k == "aloe" else SAP_PREFIX
		var text: String = id
		if text.begins_with(prefix):
			var n: String = text.trim_prefix(prefix)
			if n.is_valid_int() and str(int(n)) == n and int(n) >= 1 and int(n) <= (ALOE_COUNT if k == "aloe" else SAP_COUNT): return k
	return ""
static func valid(id: Variant) -> bool: return kind(id) != ""
static func source_name(id: Variant) -> String:
	return ALOE_NAME if kind(id) == "aloe" else SAP_NAME if kind(id) == "sap" else ""
static func info(id: Variant) -> Dictionary:
	if kind(id) == "aloe": return {"label":"Aloe","icon":ROOT + "aloe.png"}
	if kind(id) == "sap": return {"label":"Ironwood sap","icon":ROOT + "sap.png"}
	return {}
static func next_free(kind_name: String, collected: Array) -> String:
	for id in pool(kind_name):
		if not id in collected: return id
	return ""
