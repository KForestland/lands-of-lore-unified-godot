extends RefCounted
## Source prop68 ranges/gates; authored seconds and reproducible RNG adapter.
static func initial() -> Dictionary:
	return {"running":true,"enabled":false,"remaining":120.0,"seed":324508639,"region":-1,"human_return_used":[]}
static func validate(value: Variant) -> String:
	if not value is Dictionary: return "Invalid Hive curse timer."
	for key in ["running","enabled"]:
		if not value.get(key) is bool: return "Invalid Hive curse admission."
	for key in ["remaining","seed","region"]:
		var n = value.get(key)
		if not (n is int or n is float) or not is_finite(float(n)): return "Invalid Hive curse number."
	if value.remaining < 0 or value.remaining > 255: return "Invalid Hive curse countdown."
	if value.seed != floorf(value.seed) or value.seed < 0 or value.seed > 4294967295: return "Invalid Hive curse RNG."
	if value.region != floorf(value.region) or int(value.region) not in [-1,389,391,392,393,812,818,1259,1260]: return "Invalid Hive curse gate."
	var used = value.get("human_return_used",[])
	if not used is Array or used.size() > 4: return "Invalid Hive human-return history."
	var seen := {}
	for region in used:
		if not (region is int or region is float) or not is_finite(float(region)) or region != floorf(region) or int(region) not in [391,818,1259,1260] or seen.has(int(region)): return "Invalid Hive human-return history."
		seen[int(region)] = true
	return ""
static func canonical(value: Dictionary) -> Dictionary:
	var result := value.duplicate(true)
	for key in ["seed","region"]: result[key] = int(result[key])
	result.remaining = float(result.remaining)
	result.human_return_used = result.get("human_return_used",[]).map(func(n): return int(n))
	return result
static func draw(state: Dictionary, low: int, high: int) -> int:
	state.seed = (1664525*int(state.seed)+1013904223)&0xffffffff
	return low+int(state.seed)%(high-low+1)
static func enter(state: Dictionary, region: int, runes_translated: int = 0, current_form: int = 0) -> bool:
	if state.region == region: return false
	state.region = region
	# Original predicate73 tests shared14, the existing translation flag.
	if region in [812,818] and runes_translated != 0: return false
	# Command04 self-erases after requesting human, even if the callee is busy.
	# Capture admission before818 clears it with command25.
	var human: bool = region == 393 and state.enabled and current_form != 0
	if region in [391,818,1259,1260] and state.enabled and current_form != 0:
		if not state.has("human_return_used"): state.human_return_used = []
		if region not in state.human_return_used:
			state.human_return_used.append(region)
			human = true
	match region:
		389: state.running = true
		391: state.running = false
		392,812:
			state.running = true
			state.remaining = float(draw(state,120,255))
			state.enabled = true
		393,818:
			state.running = false
			state.enabled = false
	return human
