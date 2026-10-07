extends RefCounted
## Source eight stop targets. Modern lift speed and one-second polling adapter.
const STOPS := [-235.0,-427.0,-619.0,-811.0,-1003.0,-1195.0,-1387.0,-1579.0]
const SPEED := 96.0
static func initial() -> Dictionary:
	return {"height":-235.0,"target":0,"armed":false,"played_flute":false,"flute_signal":0,"poll_elapsed":0.0}
static func validate(value: Variant) -> String:
	if not value is Dictionary: return "Invalid Hive lift state."
	for key in ["height","target","flute_signal","poll_elapsed"]:
		var number = value.get(key)
		if not (number is int or number is float) or not is_finite(float(number)): return "Invalid Hive lift number."
	if value.height < STOPS[7] or value.height > STOPS[0]: return "Invalid Hive lift height."
	if value.target != floorf(value.target) or value.target < 0 or value.target > 7: return "Invalid Hive lift stop."
	if value.flute_signal != floorf(value.flute_signal) or value.flute_signal < 0 or value.flute_signal > 2: return "Invalid flute signal."
	if value.poll_elapsed < 0 or value.poll_elapsed >= 1: return "Invalid flute polling time."
	for key in ["armed","played_flute"]:
		if not value.get(key) is bool: return "Invalid Hive lift flag."
	if not value.armed and value.poll_elapsed != 0: return "Disabled flute timer retains elapsed time."
	return ""
static func play_flute(value: Dictionary) -> bool:
	if value.played_flute: return false
	value.flute_signal = 1
	return true
static func enter_trigger(value: Dictionary, region: int) -> void:
	if region == 282:
		value.flute_signal = 0
		value.armed = true
		value.poll_elapsed = 0.0
	elif region == 283:
		value.armed = false
		value.poll_elapsed = 0.0
static func advance(value: Dictionary, delta: float) -> bool:
	if not is_finite(delta) or delta <= 0: return false
	var activated := false
	var remaining := delta
	if value.armed:
		var until_poll: float = 1.0-float(value.poll_elapsed)
		if delta >= until_poll:
			value.height = move_toward(float(value.height),STOPS[int(value.target)],SPEED*until_poll)
			remaining -= until_poll
			value.poll_elapsed = fposmod(remaining,1.0)
			if not value.played_flute and value.flute_signal == 1:
				value.played_flute = true
				value.flute_signal = 2
				value.target = 0
				activated = true
		else: value.poll_elapsed += delta
	value.height = move_toward(float(value.height),STOPS[int(value.target)],SPEED*remaining)
	return activated
