extends RefCounted
## Renewable Hive Amber ("110-Amber", GLOBAL definition112, identity 0x7F859FB9). The vein regrows, so supply is
## unbounded over time; carried ids stay unique and the catalog finite through a fixed pool (a harvest takes the
## lowest id not carried). Twelve is a modern capacity adapter, not a source count.
const PREFIX := "hive:control123:Amber_"
const COUNT := 12
const SOURCE_NAME := "110-Amber"
const ICON := "res://assets/lol2/generated/hive_reaver_amber/amber.png"
static func pool() -> Array:
	var out: Array = []
	for i in range(1, COUNT + 1): out.append(PREFIX + str(i))
	return out
static func valid(id: Variant) -> bool: return id is String and id in pool()
static func next_free(collected: Array) -> String:
	for id in pool():
		if not id in collected: return id
	return ""
