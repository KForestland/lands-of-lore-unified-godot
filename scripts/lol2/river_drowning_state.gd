extends RefCounted
## User recalls roughly10–15 seconds;12 is the authored initial tuning.
const LIMIT := 12.0
var elapsed := 0.0
var dead := false
var active := false
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
