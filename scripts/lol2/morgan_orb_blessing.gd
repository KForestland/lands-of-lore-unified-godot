extends RefCounted
## Morgan (MGAR event5) held Power Orb blessing, recovered from MGAR_.WOM 5B4 and LOLG.DAT
## D6A08. Evidence: docs/morgan-orb-blessing-checks.json. Pure planner used by
## monastery_rooms.gd.
const ORB := "83-Power orb"
const HEAL := 20

## Native effect list for a held Power Orb offered to Morgan. Other held items return [].
static func offer_plan(flags: Dictionary, held: String) -> Array:
	if held != ORB: return []
	if int(flags.get("144",0)) != 0 or int(flags.get("259",0)) != 0: return [["movie",23,165,7,0]]
	return [["stop_timer"],["consume_held"],["movie",23,254,7,0],["movie",23,255,7,0],["set_flag",259],["player_D6A08",HEAL],["give_item",ORB,0]]

## D6A08(player, amount) for nonnegative amounts: no change when the player is dead or
## player229 bit1 is set, otherwise current health rises to at most the maximum.
static func heal(current: int, maximum: int, flags229 := 0, amount := HEAL) -> int:
	if current == 0 or flags229 & 2: return current
	return mini(current + amount, maximum)
