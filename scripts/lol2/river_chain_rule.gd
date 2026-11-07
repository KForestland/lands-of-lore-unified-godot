extends RefCounted
## Source callback links and counter==2 release; fresh intact session starts at zero.
const LINKS := {
	85:56, 86:56, 88:56, 89:57, 91:57, 92:57,
	93:58, 94:58, 95:58, 97:59, 98:59, 100:59,
	101:60, 102:60, 104:60, 106:61, 107:61, 108:61,
}
var cut: Dictionary = {}
var counts: Dictionary = {}
func cut_chain(prop: int) -> int:
	if not LINKS.has(prop) or cut.has(prop): return -1
	var section: int = LINKS[prop]
	if counts.get(section, 0) >= 2: return -1
	cut[prop] = true
	counts[section] = counts.get(section, 0) + 1
	return section if counts[section] == 2 else -1
