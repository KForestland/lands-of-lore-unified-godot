extends RefCounted
## Renewable Jungle beehive wax ("71-Wax", GLOBAL identity 0xAE5ADACF). Hives regrow, so wax is unlimited over time;
## carried ids stay unique and the catalog finite through a fixed pool: a harvest takes the lowest pool id not carried
## (wax consumed at the rune inscription frees its id). Six = three hives x two harvests between regrowths.
const POOL := ["jungle:beehive:Wax_1","jungle:beehive:Wax_2","jungle:beehive:Wax_3","jungle:beehive:Wax_4","jungle:beehive:Wax_5","jungle:beehive:Wax_6"]
const SOURCE_NAME := "71-Wax"
const ICON := "res://assets/lol2/generated/jungle_beehives/wax.png"
static func valid(id: Variant) -> bool: return id is String and id in POOL
static func next_free(collected: Array) -> String:
	for id in POOL:
		if not id in collected: return id
	return ""
