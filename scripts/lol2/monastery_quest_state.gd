extends RefCounted
const GlobalDefaults = preload("res://scripts/lol2/shared_global_defaults.gd")
## Functional room admission from MENT/MLIB DLLs; no native VM required.
## Live first-visit rooms use this bank; CAN later visits and Left_Village (docs/tavern-return.md) also live here.
const SIDE_FLAGS := ["170","171","172","176","177","178","181","258","259","260"]
## CAN later-visit flags (docs/tavern-return.md); absent in older saves (0).
const CAN_FLAGS := ["42","43","44"]
## Journal hint (owner rule 2026-10-27, data only; VILLAGE_INTENDED_FLOW_20261026 s7 point 10): flag 34 is Bacatta's
## farewell; going back to the tavern afterwards risks the maid betrayal (docs/tavern-return.md). Classic shows nothing.
const CAN_JOURNAL_HINTS := [
	{"when":"tavern_after_farewell","flag":"34","hint":"Bacatta's goodbye had the weight of a last word. The tavern is no place for me now; its people talk.","enhanced_guard":"Enhanced guard candidate: an optional warning before re-entering the tavern after the farewell"}]
## Village LIZ room: 268 LIZTRAN seen, 162 wax taken (docs/liz-room.md); absent in older saves (0).
const LIZ_FLAGS := ["162","268"]
## Chief's hut CHUT: 152 first visit started, 151 after line358, 153 starts Kelsrick-dead speech; 150 belongs to the unhosted attack branch
## (docs/jungle-chut-room.md); absent in older saves (0).
const CHUT_FLAGS := ["150","151","152","153","154","155","156","157","158","159"]
## CHUT branches (CHUT_BRANCHES_DECODE_20261027): 150 Anyar killed in the hut (the stone piles), 154..159 the six stones
## taken, chut_attacked the per-load static [0xD74] (entered with Kelsrick attacked: the refusal and branch A),
## anyar_present the per-load static [0xD78] (cleared by setup only when 153 is set and 150 clear: the empty hut).
## Journal hints (owner rule 2026-10-27, data only): Classic keeps these as the original plays them.
const CHUT_JOURNAL_HINTS := [
	{"when":"kelsrick_attacked_then_hut","flag":"","hint":"Anyar will not receive me again; the hut's door is barred to me since I struck Kelsrick.","enhanced_guard":"warn before striking Kelsrick that the chief's hut closes to Luther"},
	{"when":"stones","flag":"150","hint":"The chief kept six of the Ancients' stones; the piles by his seat held them all.","enhanced_guard":"none (six pickups, the piles stay)"}]
## MOFF exit visit counters and the one-shot orb gift; absent in older saves (0).
const OFFICE_FLAGS := ["145","146","148","192"]
const FLAGS := ["143","140","141","142","265","283","32","33","34","37","41","45","267","134", "135", "136", "138", "182", "183", "184", "144", "191", "264", "266", "269", "288"]
const GLOBALS := ["GV_KNOWLEDGE_OF_POWER_ORB","GV_MET_BACATTA", "GV_HAS_RUNES", "GV_RUNES_TRANSLATED"]
const LOCALS := ["Met_Dawn", "Dawn_dam_out_cave", "Gave_Dawn_Runes"]
static func initial() -> Dictionary:
	var state := {"room":"","conversation":preload("res://scripts/lol2/monastery_conversation.gd").initial(),"flags":{},"globals":{},"locals":{"Left_Village":0}}
	for key in FLAGS + SIDE_FLAGS + OFFICE_FLAGS + CAN_FLAGS + LIZ_FLAGS + CHUT_FLAGS: state.flags[key] = 0
	for key in GLOBALS: state.globals[key] = 0
	for key in GlobalDefaults.NONZERO: state.globals[key] = GlobalDefaults.initial_value(key)
	for key in LOCALS: state.locals[key] = 0
	state.locals.Met_Morgan = 0
	state.globals.GV_RIX_DEAD = 0
	state.side_actor_present = false
	return state
static func validate(state: Variant) -> String:
	if not state is Dictionary: return "Invalid monastery quest state."
	var liz_error := preload("res://scripts/lol2/liz_room_responses.gd").validate(state)
	if not liz_error.is_empty(): return liz_error
	for bank in ["flags", "globals", "locals"]:
		if not state.get(bank) is Dictionary: return "Missing monastery flag bank."
		var keys: Array = FLAGS if bank == "flags" else (GLOBALS if bank == "globals" else LOCALS)
		for key in keys:
			var value = state[bank].get(key,0) if key in ["143","GV_KNOWLEDGE_OF_POWER_ORB","140","141","142","265","283","32","33","34","37","41","45","267","135","136","138","182","183","184"] else state[bank].get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or not (value == 0 or value == 1): return "Invalid monastery flag."
	for key in SIDE_FLAGS + OFFICE_FLAGS + CAN_FLAGS + LIZ_FLAGS + CHUT_FLAGS:
		var value = state.flags.get(key,0)
		if not (value is int or value is float) or not (value == 0 or value == 1): return "Invalid monastery side-room flag."
	if not state.get("side_actor_present",false) is bool: return "Invalid monastery side-room actor."
	if not state.get("chut_attacked",false) is bool: return "Invalid chief's-hut mode."
	if not state.get("anyar_present",true) is bool: return "Invalid chief's-hut presence."
	for pair in [["locals","Met_Morgan"],["locals","Met_Kelsrick"],["globals","GV_RIX_DEAD"],["globals","GV_DAWN_TRANSLATED_RUNES"]]:
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
	if not state.get("room","") is String or not state.get("room","") in ["","MENT","MLIB","MOFF","VILLAGE","CAN","MCEL","MGAR","LIZ","CHUT"]: return "Invalid monastery room."
	var relationship = state.globals.get("GV_BACATTA_RELATIONSHIP",GlobalDefaults.initial_value("GV_BACATTA_RELATIONSHIP"))
	if not (relationship is int or relationship is float) or not is_finite(float(relationship)) or relationship != floorf(relationship) or relationship < -2147483648 or relationship > 2147483647: return "Invalid Bacatta relationship."
	if state.has("can_timer"):
		var timer = state.can_timer
		if not (timer is int or timer is float) or not is_finite(float(timer)) or timer < 0 or timer > preload("res://scripts/lol2/monastery_conversation.gd").CAN_TIMER_SECONDS: return "Invalid tavern timer."
	var left = state.locals.get("Left_Village",0)
	if not (left is int or left is float) or not is_finite(float(left)) or left != floorf(left) or left < 0 or left > 255: return "Invalid village departure count."
	if state.has("conversation"):
		var Speech = preload("res://scripts/lol2/monastery_conversation.gd")
		var error: String = Speech.validate(state.conversation)
		if not error.is_empty(): return error
		if state.conversation.sequence == "CHUT_DEAD" and state.flags.get("153",0) != 1: return "Chief death speech lost its once-only flag."
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
			if state.conversation.sequence in Speech.CAN_FIRST:
				# Bacatta's promise and the ordinary exit both follow message10 (37 cleared) and precede flag34.
				if state.flags.get("45",0) != 1 or state.flags.get("37",0) != 0 or state.flags.get("34",0) != 0: return "Bacatta's promise lacks its first visit."
				return ""
			if state.conversation.sequence == "CAN_MAID":
				if int(state.locals.get("Left_Village",0)) != 3 or state.flags.get("34",0) != 1: return "Tavern betrayal without leaving the village."
				return ""
			if state.conversation.sequence in Speech.LIZ_QUIPS:
				var line := int(state.conversation.sequence.trim_prefix("LIZ_QUIP_"))
				var choice := preload("res://scripts/lol2/liz_room_responses.gd").LINES.find(line)
				var mask := int(state.get("liz_response_mask",0))
				if state.flags.get("268",0) != 1 or mask & 3840 == 0 or mask & (1 << choice) == 0: return "LIZ response lacks its trigger/history."
				return ""
			if state.conversation.sequence == "CHUT": return ""
			if state.conversation.sequence == "CHUT_DEAD":
				return "" if state.flags.get("153",0) == 1 and state.flags.get("150",0) == 0 and int(state.globals.get("GV_KELSRICK_DEAD",0)) != 0 else "Chief death speech lacks its source admission."
			if state.conversation.sequence == "CHUT_FIRST":
				return "" if state.flags.get("152",0) == 1 else "Chief's hut speech lacks its start flag."
			# CHUT branches (CHUT_BRANCHES_DECODE_20261027): A needs the attacked mode, B flag 150, the refusal the
			# attacked mode, the stone cue flags 150 and 154.
			if state.conversation.sequence in ["CHUT_ATTACK","CHUT_REFUSE"]:
				return "" if state.get("chut_attacked",false) else "Chief's hut attack branch lacks its mode."
			if state.conversation.sequence == "CHUT_KILL":
				return "" if state.flags.get("150",0) == 1 else "Chief's hut death lacks flag 150."
			if state.conversation.sequence == "CHUT_STONE":
				return "" if state.flags.get("150",0) == 1 and state.flags.get("154",0) == 1 else "Chief's hut stone cue lacks its flags."
			var started_flag: String = {"LIZ":"268","LIZ_ENTRY":"268","LIZ_WAX":"162","CAN_REVISIT":"42","CAN_REVISIT_LATE":"43","MCEL":"170","MGAR":"258","MGAR_REPEAT":"258","MOFF_REFUSE":"140","MOFF_ORB":"143","MOFF_RUNES":"140","MLIB":"184","MLIB_ATTACK":"191","MLIB_EXIT_RUNES":"192","MOFF":"134","CAN":"45","VILLAGE":"41","CAN_EXIT":"34"}[state.conversation.sequence]
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
