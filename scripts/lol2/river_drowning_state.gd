extends RefCounted
## Time to drown: measured in the original with the DOSBox oracle 2026-10-31 (two runs from the $BRIGDE_ save in the Cave
## river: the death prompt ~15 s after submersion, +/-1.5 s); the owner recalled 10-15 s and 12 was the first tuning.
## Per-form / per-area timers are not verified (the oracle measured the Human in the Cave river).
const LIMIT := 15.0
var elapsed := 0.0
var dead := false
var active := false
## inside the water polygon, and either under the surface or airborne. Standing above the surface,
## and being outside the polygon, both pass false so advance() resets the clock.
static func counting(submerged: bool, inside: bool, airborne: bool) -> bool:
	return inside and (submerged or airborne)
func advance(delta: float, submerged: bool, running: bool = true) -> void:
	if dead or not running: return
	active = submerged
	if not submerged:
		elapsed = 0.0
		return
	elapsed = minf(LIMIT,elapsed+maxf(delta,0.0))
	dead = elapsed >= LIMIT
func reset() -> void:
	elapsed = 0.0
	dead = false
	active = false
func message() -> String:
	if dead: return "You drowned."
	return "Drowning · %d seconds to reach safety" % int(ceil(LIMIT-elapsed)) if active else ""
