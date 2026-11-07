extends RefCounted
## GLOBAL.MIX entry3984507021: the 53 initial bytes precede the named globals.
## Missing fields use original new-game values; explicit saved zero is preserved.
const NONZERO := {"GV_LUTHERS_SOUL":5,"GV_DAWN_RELATIONSHIP":1,"GV_BACATTA_RELATIONSHIP":1}
static func initial_value(name: String) -> int:
	return int(NONZERO.get(name,0))
static func read(bank: Dictionary, name: String) -> int:
	return int(bank.get(name,initial_value(name)))


## SOUL-SYSTEM (backlog 2026-11-01): Luther's good/evil value is global 0, GV_LUTHERS_SOUL. One read/add for every host,
## with the original start value (5) and the cap the native opcode-206 path already applies in the Jungle hosts (0..10).
## The cutoff that selects good/evil scenes is NOT printed by the books (grok branch_graph.md); do not invent one here.
const SOUL := "GV_LUTHERS_SOUL"
const SOUL_MIN := 0
const SOUL_MAX := 10
static func soul(bank: Dictionary) -> int:
	return clampi(read(bank, SOUL), SOUL_MIN, SOUL_MAX)
static func add_soul(bank: Dictionary, delta: int) -> int:
	bank[SOUL] = clampi(read(bank, SOUL) + delta, SOUL_MIN, SOUL_MAX)
	return int(bank[SOUL])
static func soul_after(bank: Dictionary, delta: int) -> int:
	return clampi(read(bank, SOUL) + delta, SOUL_MIN, SOUL_MAX)
