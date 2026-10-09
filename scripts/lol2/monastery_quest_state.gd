extends RefCounted
const GlobalDefaults = preload("res://scripts/lol2/shared_global_defaults.gd")
## Functional room admission from MENT/MLIB DLLs; no native VM required.
## Live first-visit rooms use this bank; Bacatta and later branches remain open.
const SIDE_FLAGS := ["170","171","172","176","177","178","181","258","259","260"]
## MOFF exit visit counters and the one-shot orb gift; absent in older saves (0).
const OFFICE_FLAGS := ["145","146","148","192"]
const FLAGS := ["143","140","141","142","265","283","32","33","34","37","41","45","267","134", "135", "136", "138", "182", "183", "184", "144", "191", "264", "266", "269", "288"]
const GLOBALS := ["GV_KNOWLEDGE_OF_POWER_ORB","GV_MET_BACATTA", "GV_HAS_RUNES", "GV_RUNES_TRANSLATED"]
const LOCALS := ["Met_Dawn", "Dawn_dam_out_cave", "Gave_Dawn_Runes"]
static func initial() -> Dictionary:
	var state := {"room":"","conversation":preload("res://scripts/lol2/monastery_conversation.gd").initial(),"flags":{},"globals":{},"locals":{"Left_Village":0}}
	for key in FLAGS + SIDE_FLAGS + OFFICE_FLAGS: state.flags[key] = 0
	for key in GLOBALS: state.globals[key] = 0
	for key in GlobalDefaults.NONZERO: state.globals[key] = GlobalDefaults.initial_value(key)
	for key in LOCALS: state.locals[key] = 0
	state.locals.Met_Morgan = 0
	state.globals.GV_RIX_DEAD = 0
	state.side_actor_present = false
	return state
static func validate(state: Variant) -> String:
	if not state is Dictionary: return "Invalid monastery quest state."
	for bank in ["flags", "globals", "locals"]:
		if not state.get(bank) is Dictionary: return "Missing monastery flag bank."
		var keys: Array = FLAGS if bank == "flags" else (GLOBALS if bank == "globals" else LOCALS)
		for key in keys:
			var value = state[bank].get(key,0) if key in ["143","GV_KNOWLEDGE_OF_POWER_ORB","140","141","142","265","283","32","33","34","37","41","45","267","135","136","138","182","183","184"] else state[bank].get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or not (value == 0 or value == 1): return "Invalid monastery flag."
	for key in SIDE_FLAGS + OFFICE_FLAGS:
		var value = state.flags.get(key,0)
		if not (value is int or value is float) or not (value == 0 or value == 1): return "Invalid monastery side-room flag."
	if not state.get("side_actor_present",false) is bool: return "Invalid monastery side-room actor."
	for pair in [["locals","Met_Morgan"],["globals","GV_RIX_DEAD"],["globals","GV_DAWN_TRANSLATED_RUNES"]]:
		var value = state[pair[0]].get(pair[1],0)
		if not (value is int or value is float) or not (value == 0 or value == 1): return "Invalid monastery side-room knowledge."
	var soul = state.globals.get("GV_LUTHERS_SOUL",GlobalDefaults.initial_value("GV_LUTHERS_SOUL"))
	if not (soul is int or soul is float) or not is_finite(float(soul)) or soul != floorf(soul) or absf(soul) > 1000: return "Invalid Luther soul value."
	if state.has("moff_load"):
		var load = state.moff_load
		if not load is Dictionary or load.size() != 2: return "Invalid office load snapshot."
		for key in ["translated","dead"]:
			var value = load.get(key)
			if not (value is int or value is float) or not (value == 0 or value == 1): return "Invalid office load snapshot."
	var pending = state.get("pending_items",[])
	if not pending is Array or pending.size() > 2: return "Invalid pending monastery items."
	for item in pending:
		if item not in [preload("res://scripts/lol2/monastery_conversation.gd").ORB,preload("res://scripts/lol2/monastery_conversation.gd").DAMPEN] or pending.count(item) != 1: return "Invalid pending monastery items."
	if not state.get("room","") is String or not state.get("room","") in ["","MENT","MLIB","MOFF","VILLAGE","CAN","MCEL","MGAR"]: return "Invalid monastery room."
	var relationship = state.globals.get("GV_BACATTA_RELATIONSHIP",GlobalDefaults.initial_value("GV_BACATTA_RELATIONSHIP"))
	if not (relationship is int or relationship is float) or not is_finite(float(relationship)) or relationship != floorf(relationship) or relationship < -2147483648 or relationship > 2147483647: return "Invalid Bacatta relationship."
	var left = state.locals.get("Left_Village",0)
	if not (left is int or left is float) or not is_finite(float(left)) or left != floorf(left) or left < 0 or left > 255: return "Invalid village departure count."
	if state.has("conversation"):
		var Speech = preload("res://scripts/lol2/monastery_conversation.gd")
		var error: String = Speech.validate(state.conversation)
		if not error.is_empty(): return error
		if Speech.active(state.conversation):
			if state.get("room","") != Speech.room_for(state.conversation.sequence): return "Speaking monastery room disagrees with save."
			if state.conversation.sequence == "MOFF_ORB" and (state.globals.get("GV_KNOWLEDGE_OF_POWER_ORB",0) == 0 or state.flags.get("283",0) != 0): return "Invalid power-orb conversation admission."
			if Speech.MOFF_LINES.has(state.conversation.sequence):
				var moff_error := _validate_moff_sequence(state)
				if not moff_error.is_empty(): return moff_error
				return ""
			if state.conversation.sequence in ["MGAR_ORB","MGAR_ORB_REFUSE"]:
				if not state.get("side_actor_present",false): return "Morgan offer lacks its actor."
				if state.conversation.sequence == "MGAR_ORB" and (state.flags.get("144",0) != 0 or state.flags.get("259",0) != 0): return "Invalid Morgan blessing admission."
				return ""
			var started_flag: String = {"MCEL":"170","MGAR":"258","MGAR_REPEAT":"258","MOFF_REFUSE":"140","MOFF_ORB":"143","MOFF_RUNES":"140","MLIB":"184","MLIB_ATTACK":"191","MLIB_EXIT_RUNES":"192","MOFF":"134","CAN":"45","VILLAGE":"41","CAN_EXIT":"34"}[state.conversation.sequence]
			var expected := 0 if state.conversation.sequence in ["VILLAGE","MOFF_REFUSE"] else 1
			if state.flags.get(started_flag,0) != expected: return "Monastery speech lacks its start flag."
	return ""
static func dawn_present(state: Dictionary) -> bool:
	# MLIB image 04cd–05a6. Named room locals and globals are distinct banks.
	if state.globals.GV_MET_BACATTA == 0: return false
	if state.locals.Dawn_dam_out_cave != 0 or state.flags["191"] == 1: return false
	if state.globals.GV_RUNES_TRANSLATED == 1 and state.flags["266"] == 1: return false
	if state.locals.Gave_Dawn_Runes == 0 and (state.flags["269"] == 1 or state.globals.GV_HAS_RUNES != 0): return false
	return true
static func enter_library(state: Dictionary) -> bool:
	# MLIB image 05e9: set only when the living Dawn actor is installed.
	if not dawn_present(state): return false
	state.locals.Met_Dawn = 1
	return true
static func office_admitted(state: Dictionary) -> bool:
	# MENT hotspot3: dead/departed Julian, Dawn meeting, and later rune gate.
	return state.flags["144"] == 0 and state.flags["288"] == 0 and state.locals.Met_Dawn != 0 and (state.flags["264"] == 0 or state.globals.GV_HAS_RUNES != 0)
static func cellar_admitted(state: Dictionary) -> bool:
	return state.flags["134"] != 0

static func bacatta_present(state: Dictionary) -> bool:
	return state.locals.get("Left_Village",0) != 3 or state.flags.get("34",0) == 0
static func enter_bacatta(state: Dictionary) -> bool:
	if not bacatta_present(state): return false
	state.globals.GV_MET_BACATTA = 1
	return true

static func side_actor_present(state: Dictionary, room: String, orb_owned := false) -> bool:
	if room == "MCEL": return state.flags.get("170",0) == 0 and state.globals.get("GV_RIX_DEAD",0) == 0
	if room == "MGAR":
		if state.flags.get("181",0) != 0 or state.flags.get("259",0) != 0: return false
		if state.flags.get("258",0) == 0 and state.flags.get("140",0) != 0: return false
		if state.flags.get("260",0) != 0 and not orb_owned: return false
		return true
	return false

## Consistency of a saved partial MOFF revisit/exit sequence with its owner state.
static func _validate_moff_sequence(state: Dictionary) -> String:
	var Speech = preload("res://scripts/lol2/monastery_conversation.gd")
	var sequence: String = state.conversation.sequence
	var cursor := int(state.conversation.cursor)
	var load: Dictionary = state.get("moff_load",{"translated":0,"dead":0})
	var f := func(id: String) -> bool: return int(state.flags.get(id,0)) != 0
	if not state.has("moff_load"): return "Office sequence lacks its load snapshot."
	if Speech.is_moff_exit(sequence) and not f.call("145"): return "Office exit lacks its visit counter."
	match sequence:
		"MOFF_TRANSLATED":
			if load.translated == 0 or not (f.call("283") or f.call("265")): return "Invalid translated office revisit."
		"MOFF_HELD_RUNES":
			if load.translated == 0 and state.globals.GV_HAS_RUNES == 0: return "Invalid rune-holding office visit."
			if load.translated == 1 and not f.call("265"): return "Invalid rune-holding office visit."
		"MOFF_REVISIT":
			if load.translated == 1 or not f.call("145"): return "Invalid office revisit."
		"MOFF_REVISIT_LATE":
			if load.translated == 1 or not f.call("146"): return "Invalid office revisit."
		"MOFF_EXIT_ORB":
			if load.translated == 0 or not f.call("283") or not f.call("148"): return "Invalid office orb exit."
			if cursor >= 3 and state.globals.GV_KNOWLEDGE_OF_POWER_ORB != 1: return "Office orb exit lost its knowledge."
		"MOFF_EXIT_RUNES":
			if load.translated == 1 or state.globals.GV_HAS_RUNES == 0: return "Invalid rune office exit."
		"MOFF_EXIT_DEAD":
			if load.dead == 0: return "Invalid office exit."
		"MOFF_EXIT_FLUTE":
			if not f.call("136") or f.call("134"): return "Invalid office flute exit."
	return ""
