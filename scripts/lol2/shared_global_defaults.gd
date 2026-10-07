extends RefCounted
## GLOBAL.MIX entry3984507021: the 53 initial bytes precede the named globals.
## Missing fields use original new-game values; explicit saved zero is preserved.
const NONZERO := {"GV_LUTHERS_SOUL":5,"GV_DAWN_RELATIONSHIP":1,"GV_BACATTA_RELATIONSHIP":1}
static func initial_value(name: String) -> int:
	return int(NONZERO.get(name,0))
static func read(bank: Dictionary, name: String) -> int:
	return int(bank.get(name,initial_value(name)))
