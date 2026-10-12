extends RefCounted
## Original audio-only room callbacks; saved LCG substitutes for native global RNG.
static var clips: Dictionary = {}
const RESPONSE_LINES := [56,21,27,58,26,33,57,20]
static func media() -> Dictionary:
	if clips.is_empty(): clips = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_rune_speech/speech.json")).clips
	return clips
static func active(state: Dictionary) -> bool:
	return not str(state.get("speech_key","")).is_empty()
static func validate(state: Dictionary) -> String:
	var key = state.get("speech_key","")
	var elapsed = state.get("speech_elapsed",0.0)
	var next = state.get("speech_next","")
	if not key is String or (not key.is_empty() and not media().has(key)): return "Invalid rune speech."
	if not next is String or next not in ["","inscription"]: return "Invalid rune speech continuation."
	if not preload("res://scripts/lol2/walkthrough_save.gd")._number(elapsed) or elapsed < 0: return "Invalid rune speech clock."
	if key.is_empty():
		if elapsed != 0 or next != "": return "Inactive rune speech has pending state."
	else:
		if state.get("room","").is_empty() or state.get("stone_playing",false) or elapsed > float(media()[key].duration): return "Invalid rune speech phase."
		if next == "inscription" and (key != "2:64" or state.room != "RUNES" or not state.get("lights",false) or not state.get("flag8",false)): return "Invalid inscription speech phase."
		if key == "100:2" and (state.room != "RUNES" or not state.get("flag7",false)): return "Stone acknowledgment requires pickup."
	for field in ["response_mask","response_seed"]:
		if not preload("res://scripts/lol2/hive_clock_runtime.gd")._integer(state.get(field,0),511 if field == "response_mask" else 0x7fffffff): return "Invalid rune response history."
	return ""
static func begin(state: Dictionary, key: String, next: String = "") -> void:
	assert(media().has(key))
	state.speech_key = key
	state.speech_elapsed = 0.0
	state.speech_next = next
static func advance(state: Dictionary, delta: float) -> bool:
	if not active(state): return false
	state.speech_elapsed = minf(float(media()[state.speech_key].duration),float(state.speech_elapsed)+maxf(0,delta))
	if state.speech_elapsed < float(media()[state.speech_key].duration): return false
	var next: String = state.speech_next
	state.speech_key = ""
	state.speech_elapsed = 0.0
	state.speech_next = ""
	if next == "inscription":
		state.flag286 = true
		state.room = "RUNECL"
	return true
static func response_plan(mask: int, draws: Array) -> Dictionary:
	if mask & 256: return {"mask":mask,"line":0,"draws_used":0}
	mask |= 256
	if mask & 255 == 255: mask &= ~255
	for index in draws.size():
		var choice := int(draws[index])
		if choice < 0 or choice > 7: return {"error":"Invalid response draw."}
		if mask & (1<<choice): continue
		return {"mask":mask|(1<<choice),"line":RESPONSE_LINES[choice],"draws_used":index+1}
	return {"error":"No unused response draw."}
static func choose_response(state: Dictionary) -> int:
	if int(state.response_mask) & 256: return 0
	var seed := int(state.response_seed)
	var draws: Array = []
	var seeds: Array = [seed]
	for index in range(8):
		seed = (1103515245*seed+12345)&0x7fffffff
		draws.append(seed%8)
		seeds.append(seed)
	var result := response_plan(int(state.response_mask),draws)
	assert(not result.has("error"))
	state.response_mask = result.mask
	state.response_seed = seeds[result.draws_used]
	return result.line
