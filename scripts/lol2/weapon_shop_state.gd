extends RefCounted
## Source event ordering with a saved movie cursor. Host presentation uses a modern clock.
const Data = preload("res://scripts/lol2/weapon_shop_data.gd")
const FLAGS := [59,60,62,63,64,65,66,67,69,71,252,253,254,256]
const ITEMS := {"5-Short swd":"jungle:weapon_shop:Short_Sword","7-Long arm":"jungle:weapon_shop:Long_Arm","42-Gargoyle br":"jungle:weapon_shop:Gargoyle_Bracers","9-Firestorm":"jungle:weapon_shop:Firestorm"}
static func initial() -> Dictionary:
	return {"room":"","flags":{},"sequence":"","cursor":0,"elapsed":0.0,"globals":{},"locals":{},"orb_seen":false}
static func flag(state: Dictionary, id: int) -> bool:
	return state.flags.get(str(id),0) != 0
static func active(state: Dictionary) -> bool:
	return not state.sequence.is_empty() and state.cursor < Data.PLANS[state.sequence].size()
static func movie_key(effect: Array) -> String:
	return "%d:%d:%d" % [effect[1],effect[2],effect[3]]
static func validate(state: Variant) -> String:
	if not state is Dictionary or not state.get("room") is String or not state.room in ["","WPNEXT","WPN"]: return "Invalid weapon shop room."
	if not state.get("orb_seen",false) is bool: return "Invalid weapon shop response history."
	for bank in ["flags","globals","locals"]:
		if not state.get(bank) is Dictionary: return "Invalid weapon shop flags."
		for key in state[bank]:
			var value = state[bank][key]
			if not key is String or not (value is int or value is float) or not (value == 0 or value == 1): return "Invalid weapon shop flag."
	if not state.get("sequence") is String or (not state.sequence.is_empty() and not Data.PLANS.has(state.sequence)): return "Invalid weapon shop sequence."
	var cursor = state.get("cursor")
	var elapsed = state.get("elapsed")
	if not (cursor is int or cursor is float) or not is_finite(cursor) or cursor < 0 or cursor != floorf(cursor): return "Invalid weapon shop cursor."
	if not (elapsed is int or elapsed is float) or not is_finite(elapsed) or elapsed < 0: return "Invalid weapon shop clock."
	if state.sequence.is_empty():
		return "" if cursor == 0 and elapsed == 0 else "Unstarted weapon shop sequence progressed."
	var plan: Array = Data.PLANS[state.sequence]
	if cursor > plan.size(): return "Invalid weapon shop cursor."
	if cursor == plan.size():
		if elapsed != 0: return "Completed weapon shop sequence has a clock."
	else:
		if state.room != "WPN" or plan[int(cursor)][0] != "movie": return "Invalid weapon shop speaking state."
		if elapsed >= Data.DURATIONS[movie_key(plan[int(cursor)])]: return "Weapon shop movie already ended."
	for i in range(int(cursor)):
		var effect: Array = plan[i]
		if effect[0] == "set_flag" and not flag(state,int(effect[1])): return "Weapon shop lost a completed flag."
		if effect[0] == "set_global" and state.globals.get(effect[1],0) != effect[2]: return "Weapon shop lost completed knowledge."
	return ""
static func enter_exterior(state: Dictionary) -> bool:
	if state.room != "" or active(state): return false
	state.room = "WPNEXT"
	state.flags["256"] = 0 # WPNEXT setup clears this flag.
	return true
## Entering WPN. Original room initialization (callback1, WPN_.WOM 0x672..0x67F) ends with set_local Met_Kityara=1 on
## every path: the first meeting is earned by entering her shop (read by the Jungle Kityara follow-up, local35).
static func enter_room(state: Dictionary) -> void:
	state.room = "WPN"
	state.orb_seen = false
	state.locals["Met_Kityara"] = 1
static func admitted(state: Dictionary, power_orb_owned: bool = false) -> bool:
	var blocked := flag(state,71) and not power_orb_owned
	blocked = blocked or state.locals.get("Kityara_No_Home",0) != 0 or state.locals.get("kityara_gave_knife",0) != 0
	if flag(state,253) or state.locals.get("Kityara_Given_Orb",0) != 0 or state.globals.get("GV_KITYARA_DEAD",0) != 0: blocked = false
	return not blocked
static func begin(state: Dictionary, sequence: String) -> Array:
	if active(state) or not Data.PLANS.has(sequence): return []
	state.sequence = sequence
	state.cursor = 0
	state.elapsed = 0.0
	return advance(state,0.0)
static func advance(state: Dictionary, delta: float) -> Array:
	var host_effects: Array = []
	if not is_finite(delta) or delta < 0: return host_effects
	while active(state):
		var effect: Array = Data.PLANS[state.sequence][int(state.cursor)]
		if effect[0] == "movie":
			var remaining: float = Data.DURATIONS[movie_key(effect)] - float(state.elapsed)
			if delta < remaining:
				state.elapsed += delta
				break
			delta -= remaining
			state.elapsed = 0.0
		elif effect[0] == "set_flag": state.flags[str(effect[1])] = effect[2] if effect.size() > 2 else 1
		elif effect[0] == "clear_flag": state.flags[str(effect[1])] = 0
		elif effect[0] == "set_global":
			state.globals[effect[1]] = effect[2]
			host_effects.append(effect)
		elif effect[0] == "set_local": state.locals[effect[1]] = effect[2]
		else: host_effects.append(effect)
		state.cursor = int(state.cursor)+1
	return host_effects
static func action(state: Dictionary, name: String) -> Array:
	if state.room != "WPN" or active(state) or state.globals.get("GV_KITYARA_DEAD",0) != 0: return []
	match name:
		"longarm":
			if flag(state,60): return []
		"gargoyle":
			if flag(state,64): return []
			if flag(state,62): name = "gargoyle_after_sword"
		"shortsword":
			if flag(state,62): return []
		"orb":
			if state.get("orb_seen",false) and flag(state,254): return []
			state.orb_seen = true
			if flag(state,254): name = "orb_known"
			elif state.globals.get("GV_KNOWLEDGE_OF_POWER_ORB",0) != 0: name = "orb_preknown"
		_: return []
	return begin(state,name)
static func offer(state: Dictionary, source_name: String) -> Array:
	if state.room!="WPN" or active(state) or state.globals.get("GV_KITYARA_DEAD",0) != 0: return []
	if source_name=="83-Power orb": return begin(state,"offer_orb_repeat" if flag(state,63) else "offer_orb")
	if source_name=="10-Th Dagger": return begin(state,"offer_dagger")
	return []
