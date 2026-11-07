extends RefCounted
## Native f133c response history; saved per-room LCG substitutes for native global RNG/history.
const LINES := [56,21,27,58,26,33,57,20]
static func choose(state: Dictionary, hotspot: int) -> int:
	if hotspot < 1 or hotspot > 4: return 0
	var trigger := 1 << (hotspot + 7)
	var mask := int(state.get("liz_response_mask",0))
	if mask & trigger: return 0
	mask |= trigger
	if mask & 255 == 255: mask &= ~255
	var seed := int(state.get("liz_response_seed",1))
	# The low three LCG bits visit all eight choices; rejected draws consume RNG state.
	for attempt in 8:
		seed = (1103515245 * seed + 12345) & 0x7fffffff
		var choice := seed % 8
		if mask & (1 << choice): continue
		state.liz_response_mask = mask | (1 << choice)
		state.liz_response_seed = seed
		return LINES[choice]
	return 0
static func reset_triggers(state: Dictionary) -> void:
	state.liz_response_mask = int(state.get("liz_response_mask",0)) & 255
static func validate(state: Dictionary) -> String:
	for pair in [["liz_response_mask",4095,0],["liz_response_seed",0x7fffffff,1]]:
		var value = state.get(pair[0],pair[2])
		if not (value is int or value is float) or not is_finite(float(value)) or value != floorf(value) or value < 0 or value > pair[1]:
			return "Invalid LIZ response history."
	return ""
