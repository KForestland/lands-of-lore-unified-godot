extends RefCounted
## Required player fields for a CURRENT area departure (docs/player-continuity.md). The sender checks the packet it
## just built before leaving: if one is missing, travel is refused and the source area stays usable. Receivers and
## saves keep their legacy defaults, so old saves and packets still load unchanged.
const REQUIRED := ["collected", "item_effects", "equipped_item", "equipped_armor", "health", "player_form", "curse", "magic", "fighting"]
static func missing_error(packet: Variant) -> String:
	if not packet is Dictionary: return "Invalid area departure."
	var missing: Array = REQUIRED.filter(func(field): return not packet.has(field))
	return "" if missing.is_empty() else "Player state incomplete (%s)." % ", ".join(missing)
