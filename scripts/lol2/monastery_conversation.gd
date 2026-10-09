extends RefCounted
const GlobalDefaults = preload("res://scripts/lol2/shared_global_defaults.gd")
## First-visit village, Bacatta and monastery DLL calls; modern saved playback clock.
const FLUTE := "monastery:item94:Iron_Flute"
const ORB := "monastery:item83:Power_Orb"
## MLIB message8 grant (image 0x766): GLOBAL definition72 "70-Dampen ch" (docs/monastery-dawn-runes-source.json).
const DAMPEN := "monastery:item70:Dampen_charm"
## Original item names (as compared by room DLLs) for items this layer grants.
const SOURCE_ITEMS := {"94-Iron flute":FLUTE,"83-Power orb":ORB,"70-Dampen ch":DAMPEN}
## MOFF message9/message8 branches beyond the first visit (docs/moff-revisit-checks.json).
const MOFF_LINES := {"MOFF_REVISIT":[400,401,402,403,404,406],"MOFF_REVISIT_LATE":[450,451,452,453],"MOFF_HELD_RUNES":[500,501,502,503,504,505],
	"MOFF_TRANSLATED":[600,601,602,603,604],"MOFF_EXIT_FIRST":[384,385],"MOFF_EXIT_SECOND":[407,408,409,410,411,412],"MOFF_EXIT_LATER":[407],
	"MOFF_EXIT_RUNES":[506,507],"MOFF_EXIT_ORB":[564,565,566,567],"MOFF_EXIT_DEAD":[386,387],"MOFF_EXIT_FLUTE":[366,367,368,369,370,371,372,373,374]}
const MOFF_EXITS := ["MOFF_EXIT_FIRST","MOFF_EXIT_SECOND","MOFF_EXIT_LATER","MOFF_EXIT_RUNES","MOFF_EXIT_ORB","MOFF_EXIT_DEAD","MOFF_EXIT_FLUTE"]
const FRAMES := {
	"MLIB_ATTACK":[97],
	"MLIB_EXIT_RUNES":[20,36,32,63,21,111],
	"MGAR_ORB":[151,358],"MGAR_ORB_REFUSE":[99],
	"MCEL":[53, 31, 40, 57, 51, 55, 23, 61, 44, 54, 31, 70, 64],
	"MGAR":[69, 76, 68, 69, 35, 35, 117, 101, 84, 220, 55, 180, 34, 148],
	"MGAR_REPEAT":[62, 60, 66, 102],

	"MOFF_REFUSE":[52,105],
	"MOFF_ORB":[75,15,125],
	"MOFF_RUNES":[59, 28, 80, 18, 16, 292, 46, 67, 51, 26, 158, 92, 77],
	"CAN_EXIT":[0,0,46,21],
	"VILLAGE":[148],
	"CAN":[127,135,0,0,61,71,94,121,0,0,118,44],
	"MLIB":[80,12,53,28,75,42,27,32,52,25,54,139,63,56,70],
	"MOFF":[38,37,54,67,49,29,65,53,121,82,51,57,83,205,41,63,51,36,72,40,42,47,32],
	"MOFF_REVISIT":[59,45,50,29,123,123],"MOFF_REVISIT_LATE":[43,26,71,22],"MOFF_HELD_RUNES":[50,63,42,48,28,62],"MOFF_TRANSLATED":[35,20,63,31,78],
	"MOFF_EXIT_FIRST":[68,166],"MOFF_EXIT_SECOND":[38,14,35,59,35,62],"MOFF_EXIT_LATER":[38],"MOFF_EXIT_RUNES":[39,75],"MOFF_EXIT_ORB":[41,40,49,82],"MOFF_EXIT_DEAD":[0,0],
	"MOFF_EXIT_FLUTE":[41,63,51,36,72,40,42,47,32]}
const SAMPLES := {"MLIB_ATTACK":[153614],"MLIB_EXIT_RUNES":[40424,63944,58064,103634,41894,174194],"MGAR_ORB":[232994,537284],"MGAR_ORB_REFUSE":[156554],"MCEL":[88934, 56594, 69824, 94814, 85994, 91874, 44834, 100694, 75704, 90404, 56594, 113924, 105104],"MGAR":[112454, 122744, 110984, 112454, 62474, 62474, 183014, 159494, 134504, 334424, 91874, 275624, 61004, 228584],"MGAR_REPEAT":[102164, 99224, 108044, 160964],"MOFF_REFUSE":[87464,165374],"MOFF_ORB":[121274,33074,194774],"MOFF_RUNES":[97754, 52184, 128624, 37484, 34544, 440264, 78644, 109514, 85994, 49244, 243284, 146264, 124214],"CAN_EXIT":[15872,41984,78644,41894],"VILLAGE":[228584],"CAN":[197714,209474,91264,86272,100694,115394,149204,188894,48000,72128,184484,75704],"MLIB": [128624, 28664, 88934, 52184, 121274, 72764, 50714, 58064, 87464, 47774, 90404, 215354, 103634, 93344, 113924], "MOFF": [66884, 65414, 90404, 109514, 83054, 53654, 106574, 88934, 188894, 131564, 85994, 94814, 133034, 312374, 71294, 103634, 85994, 63944, 116864, 69824, 72764, 80114, 58064],"MOFF_REVISIT":[97754,77174,84524,53654,191834,191834],"MOFF_REVISIT_LATE":[74234,49244,115394,43364],"MOFF_HELD_RUNES":[84524,103634,72764,81584,52184,102164],"MOFF_TRANSLATED":[62474,40424,103634,56594,125684],"MOFF_EXIT_FIRST":[110984,255044],"MOFF_EXIT_SECOND":[66884,31604,62474,97754,62474,102164],"MOFF_EXIT_LATER":[66884],"MOFF_EXIT_RUNES":[68354,121274],"MOFF_EXIT_ORB":[71294,69824,83054,131564],"MOFF_EXIT_DEAD":[39168,41344]}
static func duration(sequence: String, index: int) -> float:
	if sequence == "MOFF_EXIT_FLUTE": return duration("MOFF",index+14)
	return maxf(float(FRAMES[sequence][index])/15.0,float(SAMPLES[sequence][index])/22050.0)
const FLAGS := ["134","135","136","138","182","183","184"]
static func initial() -> Dictionary:
	return {"sequence":"","cursor":0,"elapsed":0.0}
static func validate(s: Variant) -> String:
	if not s is Dictionary or not s.get("sequence") is String or not s.sequence in ["","MCEL","MGAR","MGAR_REPEAT","MGAR_ORB","MGAR_ORB_REFUSE","MLIB","MLIB_ATTACK","MLIB_EXIT_RUNES","MOFF","MOFF_RUNES","MOFF_REFUSE","MOFF_ORB","VILLAGE","CAN","CAN_EXIT"] + MOFF_LINES.keys(): return "Invalid monastery conversation."
	var cursor = s.get("cursor")
	var elapsed = s.get("elapsed")
	if not (cursor is int or cursor is float) or not is_finite(float(cursor)) or cursor != floorf(cursor) or cursor < 0: return "Invalid monastery movie index."
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed < 0: return "Invalid monastery movie clock."
	if s.sequence.is_empty():
		if cursor != 0 or elapsed != 0: return "Unstarted monastery movie progressed."
	else:
		var frames: Array = FRAMES[s.sequence]
		if cursor > frames.size(): return "Monastery movie index out of range."
		if cursor == frames.size():
			if elapsed != 0: return "Completed monastery movie has a clock."
		elif elapsed >= duration(s.sequence,int(cursor)): return "Monastery movie already ended."
	return ""
static func active(s: Dictionary) -> bool:
	return not s.sequence.is_empty() and s.cursor < FRAMES[s.sequence].size()
static func begin(state: Dictionary, room: String) -> bool:
	var s: Dictionary = state.get("conversation",initial())
	if active(s) or not FRAMES.has(room) or room in ["MGAR_REPEAT","CAN_EXIT","MOFF_RUNES","MOFF_REFUSE","MOFF_ORB","MLIB_ATTACK"]: return false
	var Room = load("res://scripts/lol2/monastery_quest_state.gd")
	if room == "VILLAGE":
		if state.flags.get("41",0) != 0: return false
	elif room == "CAN":
		if not Room.enter_bacatta(state) or state.flags.get("34",0) != 0 or state.flags.get("45",0) != 0: return false
		state.flags["45"] = 1
	elif room == "MLIB":
		if not Room.enter_library(state) or state.flags.get("184",0) != 0: return false
		state.flags["184"] = 1
	elif room == "MCEL":
		if not state.get("side_actor_present",false) or state.locals.Met_Dawn == 0 or state.flags.get("170",0) != 0: return false
		state.flags["170"] = 1
	elif room == "MGAR":
		if not state.get("side_actor_present",false): return false
		if state.flags.get("258",0) == 0: state.flags["258"] = 1
		else: room = "MGAR_REPEAT"
	else:
		if not Room.office_admitted(state): return false
		# Message1 snapshots the translation global and Julian's death flag (DLL statics 1524/1520).
		state.moff_load = {"translated":int(state.globals.GV_RUNES_TRANSLATED != 0),"dead":int(state.flags.get("144",0) != 0)}
		var chosen := _moff_entry_sequence(state)
		if chosen.is_empty(): return false
		room = chosen
	state.room = room_for(room)
	state.conversation = {"sequence":room,"cursor":0,"elapsed":0.0}
	return true
static func advance(state: Dictionary, delta: float) -> Array:
	var rewards: Array = []
	if not is_finite(delta) or delta < 0: return rewards
	var s: Dictionary = state.get("conversation",initial())
	while active(s) and delta > 0:
		var duration: float = duration(s.sequence,int(s.cursor))
		var remaining := duration-float(s.elapsed)
		if delta < remaining:
			s.elapsed += delta
			break
		delta -= remaining
		var finished := int(s.cursor)
		s.cursor += 1
		s.elapsed = 0.0
		if s.sequence == "MGAR_ORB" and finished == 1:
			state.flags["259"] = 1
			rewards.append({"morgan_heal":20})
			rewards.append(ORB)
		elif s.sequence == "MGAR" and finished == 13:
			for key in ["176","177","178"]: state.flags[key] = 1
		elif s.sequence == "MGAR_REPEAT" and finished == 3:
			state.flags["260"] = 1
		elif s.sequence == "VILLAGE":
			state.flags["41"] = 1
		elif s.sequence == "CAN":
			if finished == 3: state.flags["32"] = 1
			if finished == 7: state.flags["33"] = 1
			if finished == 11: state.flags["37"] = 1
		elif s.sequence == "MLIB":
			if finished == 4: state.flags["182"] = 1
			if finished == 11: state.flags["183"] = 1
		elif s.sequence == "MLIB_EXIT_RUNES":
			# 0x766: the charm is given after movie 666; the globals and flag266 follow movie 668.
			if finished == 3: rewards.append(DAMPEN)
			if finished == 5:
				state.globals.GV_RUNES_TRANSLATED = 1
				state.globals.GV_DAWN_TRANSLATED_RUNES = 1
				state.flags["266"] = 1
		elif s.sequence == "MOFF_RUNES":
			if finished == 5: state.flags["141"] = 1
			if finished == 7: state.flags["142"] = 1
			if finished == 12:
				state.globals.GV_RUNES_TRANSLATED = 1
				state.flags["283"] = 1
		elif s.sequence == "MOFF_TRANSLATED":
			if finished == 4: state.flags["288"] = 1
		elif s.sequence == "MOFF_EXIT_ORB":
			# Grant, knowledge and soul follow line566; line567 plays before the exit.
			if finished == 2:
				rewards.append(ORB)
				state.globals.GV_KNOWLEDGE_OF_POWER_ORB = 1
				state.globals.GV_LUTHERS_SOUL = int(state.globals.get("GV_LUTHERS_SOUL",GlobalDefaults.initial_value("GV_LUTHERS_SOUL")))+1
		elif s.sequence == "MOFF_EXIT_FLUTE":
			if finished == 6:
				rewards.append(FLUTE)
				state.flags["138"] = 1
		elif s.sequence == "MOFF":
			if finished == 9: state.flags["135"] = 1
			if finished == 13: state.flags["136"] = 1
			if finished == 20 and state.flags["144"] == 0 and state.flags.get("138",0) == 0:
				state.flags["138"] = 1
				rewards.append(FLUTE)
	return rewards

static func room_for(sequence: String) -> String:
	if sequence in ["MLIB_ATTACK","MLIB_EXIT_RUNES"]: return "MLIB"
	if sequence in ["MGAR_REPEAT","MGAR_ORB","MGAR_ORB_REFUSE"]: return "MGAR"
	return "CAN" if sequence == "CAN_EXIT" else ("MOFF" if sequence in ["MOFF_RUNES","MOFF_REFUSE","MOFF_ORB"] or MOFF_LINES.has(sequence) else sequence)
## Library messages6/7 (player Use Weapon / Cast Spell inside the room): native MLIB 0x98F/0xF09 effects applied, then
## the reaction movie 3/773. Dawn is installed only when dawn_present() (DLL 0x125C); a later attack in the same load
## finds her gone (flag191). Returns false when the handler does nothing.
static func begin_attack(state: Dictionary, message: int) -> bool:
	var s: Dictionary = state.get("conversation",initial())
	if active(s) or state.get("room","") != "MLIB": return false
	var Room = load("res://scripts/lol2/monastery_quest_state.gd")
	var Attack = load("res://scripts/lol2/monastery_library_attack.gd")
	var out: Dictionary = Attack.attacked(message,Room.dawn_present(state),false,state.flags,state.globals)
	if out.effects.is_empty(): return false
	Attack.apply(state,out.effects)
	state.conversation = {"sequence":"MLIB_ATTACK","cursor":0,"elapsed":0.0}
	return true
static func begin_exit(state: Dictionary) -> void:
	state.flags["34"] = 1
	state.flags["37"] = 0
	state.globals.GV_BACATTA_RELATIONSHIP = 0
	state.conversation = {"sequence":"CAN_EXIT","cursor":0,"elapsed":0.0}

## Message9 runtime: instant effects precede the named sequence ("" = silent entry).
static func _moff_entry_sequence(state: Dictionary) -> String:
	var flags: Dictionary = state.flags
	var runes := int(state.globals.GV_HAS_RUNES != 0)
	if state.moff_load.translated:
		if flags.get("265",0) != 0 or flags.get("283",0) != 0: return "MOFF_TRANSLATED"
		flags["265"] = 1
		return "MOFF_HELD_RUNES"
	if runes and flags.get("134",0) == 0: return "" # Runes before the first meeting: not reachable (flute precedes runes).
	if runes: return "MOFF_HELD_RUNES"
	if flags.get("134",0) == 0:
		flags["134"] = 1
		return "MOFF"
	if flags.get("146",0) != 0: return "MOFF_REVISIT_LATE"
	if flags.get("145",0) != 0: return "MOFF_REVISIT"
	return ""
## Message8 runtime. Applies the leading instant effects; returns true while a
## sequence holds the room, false when the player leaves MOFF immediately.
static func begin_moff_exit(state: Dictionary) -> bool:
	if active(state.get("conversation",initial())) or state.get("room","") != "MOFF": return false
	# Older saves made inside the office predate the load snapshot. 0 is exact for the
	# translation visit; an old silent post-translation revisit defers the gift one visit.
	if not state.has("moff_load"): state.moff_load = {"translated":0,"dead":int(state.flags.get("144",0) != 0)}
	var load: Dictionary = state.moff_load
	var plan := moff_exit_plan(state.flags,int(load.translated),int(state.globals.GV_HAS_RUNES != 0),int(load.dead),int(state.globals.get("GV_LUTHERS_SOUL",GlobalDefaults.initial_value("GV_LUTHERS_SOUL"))))
	var sequence := ""
	for effect in plan.effects:
		if effect[0] in ["movie","movie_flags"]: break
		if effect[0] == "set_flag": state.flags[str(effect[1])] = 1
	for name in MOFF_EXITS:
		if _plan_lines(plan) == MOFF_LINES[name]: sequence = name
	if sequence.is_empty():
		state.room = "MENT"
		return false
	state.conversation = {"sequence":sequence,"cursor":0,"elapsed":0.0}
	return true
static func _plan_lines(plan: Dictionary) -> Array:
	var lines: Array = []
	for effect in plan.effects:
		if effect[0] in ["movie","movie_flags"]: lines.append(int(effect[2]))
	return lines
## MLIB message8 (exit request, image 0x6C0): Dawn translates the runes and gives the Dampen charm once the player has
## given her the wax runes (Gave_Dawn_Runes), flag192 is clear and she is installed (dawn_present). Returns true while
## the sequence holds the room; false when the player leaves to MENT immediately (the 774/775 branch is not staged).
static func begin_mlib_exit(state: Dictionary) -> bool:
	if active(state.get("conversation",initial())) or state.get("room","") != "MLIB": return false
	var Room = load("res://scripts/lol2/monastery_quest_state.gd")
	if int(state.locals.get("Gave_Dawn_Runes",0)) != 1 or int(state.flags.get("192",0)) != 0 or not Room.dawn_present(state): return false
	state.flags["192"] = 1
	state.conversation = {"sequence":"MLIB_EXIT_RUNES","cursor":0,"elapsed":0.0}
	return true

static func is_moff_exit(sequence: String) -> bool:
	return sequence in MOFF_EXITS

## Native-format planners, compared with every oracle case by tests/moff_revisit_plan_test.gd.
static func _m(speaker: int, line: int, presentation: int = 0) -> Array:
	return ["movie",speaker,line,7,presentation]
const FIRST_VISIT := [[351,128],[352,128],[353,0],[354,0],[355,128],[356,0],[357,0],[358,224],[360,0],[361,0],["135"],[362,160],[363,0],[364,0],[365,0],["136"],[366,160],[367,0],[368,0],[369,0],[370,0],[371,128],[372,0],["flute"],[373,0],[374,128]]
static func _first_visit(effects: Array, dead: int, from: int = 0) -> void:
	for index in range(from,FIRST_VISIT.size()):
		var row: Array = FIRST_VISIT[index]
		if row[0] is String:
			if row[0] == "flute":
				if dead == 0: effects.append_array([["give_item","94-Iron flute",0],["set_flag",138]])
			else: effects.append(["set_flag",int(row[0])])
		else: effects.append(_m(22,row[0],row[1]))
static func moff_entry_plan(flags: Dictionary, translated: int, runes: int, dead: int = 0) -> Dictionary:
	var f := func(id: int) -> bool: return int(flags.get(str(id),0)) != 0
	var effects: Array = []
	var held := [_m(22,500),_m(22,501,128),_m(22,502),_m(22,503,128),_m(22,504),_m(22,505)]
	if translated:
		if f.call(265) or f.call(283):
			effects.append_array([_m(22,600,128),_m(22,601),_m(22,602),_m(22,603),_m(22,604),["set_flag",288]])
		else:
			effects.append(["set_flag",265])
			effects.append_array(held)
		return {"handled":1,"effects":effects}
	if runes: effects.append_array(held)
	if not f.call(134):
		effects.append(["set_flag",134])
		_first_visit(effects,dead)
		return {"handled":1,"effects":effects}
	if f.call(146) and not runes:
		effects.append_array([_m(22,450),_m(22,451),_m(22,452),_m(22,453,128)])
		return {"handled":1,"effects":effects}
	if f.call(145) and not runes:
		effects.append_array([_m(22,400),_m(22,401,128),_m(22,402,128),_m(22,403),_m(22,404),_m(22,406)])
		return {"handled":1,"effects":effects}
	return {"handled":0,"effects":effects}
static func moff_exit_plan(flags: Dictionary, translated: int, runes: int, dead: int, soul: int) -> Dictionary:
	var current := flags.duplicate()
	var f := func(id: int) -> bool: return int(current.get(str(id),0)) != 0
	var effects: Array = []
	for id in [145,146,264]:
		if not f.call(id):
			effects.append(["set_flag",id])
			current[str(id)] = 1
			break
	if dead: effects.append_array([_m(1,386),_m(1,387)])
	elif f.call(265): pass
	elif not f.call(134) and not f.call(136):
		effects.append(["set_flag",136])
		_first_visit(effects,0,16)
	elif translated and f.call(283) and not f.call(148):
		effects.append_array([["set_flag",148],_m(22,564,128),_m(22,565,128),_m(22,566),["give_item","83-Power orb",0],
			["set_named","GV_KNOWLEDGE_OF_POWER_ORB",1],["set_named","GV_LUTHERS_SOUL",soul+1],_m(22,567)])
	elif runes:
		if not translated: effects.append_array([_m(22,506),_m(22,507)])
	elif f.call(264): effects.append(_m(22,407,128))
	elif f.call(146): effects.append_array([_m(22,407,128),_m(22,408),_m(22,409),_m(22,410),_m(22,411,128),_m(22,412,192)])
	else: effects.append_array([_m(22,384),_m(22,385)])
	effects.append(["exit_room"])
	return {"handled":1,"effects":effects}
