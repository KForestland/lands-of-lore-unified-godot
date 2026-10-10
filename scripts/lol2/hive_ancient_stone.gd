extends RefCounted
## Source RUNES hotspot4: film, then item and flag7. Numeric follow-up remains open.
const ITEM := "hive:runes:Ancients_Stone"
const ROOT := "res://assets/lol2/generated/hive_ancient_stone/"
const DURATION := 55.0/15.0
static func validate(state: Dictionary) -> String:
	if not state.get("flag7",false) is bool or not state.get("stone_playing",false) is bool: return "Invalid Ancient Stone flags."
	var elapsed = state.get("stone_elapsed",0.0)
	if not preload("res://scripts/lol2/walkthrough_save.gd")._number(elapsed) or elapsed < 0 or elapsed > DURATION: return "Invalid Ancient Stone movie time."
	if state.get("stone_playing",false):
		if state.get("room","") != "RUNES" or not state.get("lights",false) or state.get("flag7",false): return "Invalid Ancient Stone pickup phase."
	elif elapsed != 0: return "Inactive Ancient Stone movie has a clock."
	return ""
static func begin(state: Dictionary, items: Array) -> bool:
	if state.room != "RUNES" or not state.lights or state.get("flag7",false) or state.get("stone_playing",false) or ITEM in items or items.size() >= 23: return false
	state.stone_playing = true
	state.stone_elapsed = 0.0
	return true
static func advance(state: Dictionary, items: Array, delta: float) -> bool:
	if not state.get("stone_playing",false): return false
	state.stone_elapsed = minf(DURATION,float(state.stone_elapsed)+maxf(delta,0.0))
	if state.stone_elapsed < DURATION: return false
	state.stone_playing = false
	state.stone_elapsed = 0.0
	if ITEM not in items:
		if items.size() >= 23: return true
		items.append(ITEM)
	state.flag7 = true
	return true
