extends RefCounted
## Source-granted identities are distinct from shop/exhibit copies of the same item.
const SWORD:="cave:captain:Short_Sword"
const ARMOR:="cave:captain:Burnt_Chain"
const NAMES:={"5-Short swd":SWORD,"37-Brnt Chain":ARMOR}
static func valid(id: Variant) -> bool:return id is String and id in [SWORD,ARMOR]
static func from_grants(grants: Array) -> Array:
	var result: Array=[]
	for name in grants:
		if NAMES.has(name) and NAMES[name] not in result:result.append(NAMES[name])
	return result
static func label(id: String) -> String:return "Short Sword" if id==SWORD else "Burnt Chain"
static func icon(id: String) -> String:
	return "res://assets/lol2/generated/cave_captain_items/"+("Short_Sword" if id==SWORD else "Burnt_Chain")+".png"

## Source grants and the separately saved fighting-death pickup share one captain item identity.
static func from_checkpoint(saved: Dictionary) -> Array:
	var result := from_grants(saved.source.granted)
	if saved.get("loot",{}).get("taken",false) and SWORD not in result: result.append(SWORD)
	return result
