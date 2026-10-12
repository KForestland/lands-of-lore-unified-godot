extends RefCounted
## Source D8A1C accumulation/level loop. Presentation and RNG ownership are external.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func apply_reward(player: Variant, award: Variant, draws: Variant) -> Dictionary:
	if not player is Dictionary or not Numbers._integer(award,6375) or not draws is Array: return {"error":"Invalid reward application."}
	for field in ["experience","condition","maximum","health","stat151","stat155"]:
		if not Numbers._integer(player.get(field),0xffffffff): return {"error":"Invalid reward player field: "+field}
	if not Numbers._integer(player.get("level"),30): return {"error":"Unsupported player reward level."}
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_reward_thresholds.json"))
	if not source is Dictionary or not source.get("thresholds") is Array or source.thresholds.size()!=31: return {"error":"Invalid reward threshold source."}
	for threshold in source.thresholds:
		if not Numbers._integer(threshold,0x7fffffff): return {"error":"Invalid reward threshold."}
	var state: Dictionary = player.duplicate(true)
	for field in ["experience","condition","maximum","health","stat151","stat155","level"]: state[field]=int(state[field])
	state.experience=(state.experience+int(award))&0xffffffff
	if state.experience>=0x7fffffff: state.experience=0x7ffffff0
	var cursor := 0
	var maxima: Array[int] = []
	while state.level<=30 and state.experience>=int(source.thresholds[state.level]):
		if cursor+3>draws.size(): return {"error":"Missing reward random draws."}
		for index in range(3):
			if not Numbers._integer(draws[cursor+index],95 if index==0 else 63): return {"error":"Invalid reward random draw."}
		state.experience-=int(source.thresholds[state.level]);state.level+=1
		var gain := 6+(int(draws[cursor])>>5)
		state.maximum=(state.maximum+gain)&0xffffffff
		if state.condition==0: state.health=(state.health+gain)&0xffffffff
		state.stat151=(state.stat151+1+(int(draws[cursor+1])>>5))&0xffffffff
		state.stat155=(state.stat155+1+(int(draws[cursor+2])>>5))&0xffffffff
		cursor+=3;maxima.append_array([95,63,63])
	return {"state":state,"draws_used":cursor,"random_maxima":maxima,"leveled":state.level!=int(player.level)}

static func restore(saved: Variant) -> Dictionary:
	if not saved is Dictionary or not Numbers._integer(saved.get("version"),1) or int(saved.version)!=1 or not saved.get("player") is Dictionary: return {"error":"Invalid reward checkpoint."}
	var state: Dictionary = saved.player.duplicate(true)
	for field in ["experience","condition","maximum","health","stat151","stat155"]:
		if not Numbers._integer(state.get(field),0xffffffff): return {"error":"Invalid saved reward field: "+field}
		state[field]=int(state[field])
	if not Numbers._integer(state.get("level"),30): return {"error":"Invalid saved reward level."}
	state.level=int(state.level)
	return {"checkpoint":{"version":1,"player":state}}

static func award_checkpoint(saved: Variant, award: Variant, draws: Variant) -> Dictionary:
	var checked := restore(saved)
	if checked.has("error"): return checked
	var result := apply_reward(checked.checkpoint.player,award,draws)
	if result.has("error"): return result
	result.checkpoint={"version":1,"player":result.state.duplicate(true)}
	return result
