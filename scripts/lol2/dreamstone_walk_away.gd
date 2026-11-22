extends RefCounted
## Owner rule via lead 2026-11-16 (Grok r19o3 Temple stop): the Dreamstone cannot be left behind. Once a slot has done
## its work (the Temple spiral risen, the Citadel exit or the Temple entrance open) and Luther walks away with the stone
## still in it, the stone returns to his pack with a line. The original slots keep it until it is taken back (the
## Temple slot72 retrieval is not decoded); the chalice in the Chamber of Voices needs it. DEVIATIONS row.
const LEAVE := 220.0  # beyond the slots' 145/170 reach
const LINE := "You take the Dreamstone back."
static func due(host: Node, done: bool, occupied: String, point: Vector3) -> bool:
	if not done or occupied.is_empty() or not host.starting_magic.world_active(): return false
	return host.carried_collected.size() < 64 and host.player.global_position.distance_to(point) > LEAVE
